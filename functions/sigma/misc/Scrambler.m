classdef Scrambler
%% class Scrambler
%
% Requires: the Image Processing Toolbox for padarray().
%
% Written by P. DERIAN 2017-06-08
    properties(SetAccess=private)
        gridSize = [128, 128]           % the size of the grid
        patchDim = 3                    % the dimension of the (square, cubic) patch
        boundaryCondition = 'circular'  % the boundary condition        
        % these above are the main properties (and default values)
        
        nDimensions                     % the number of dimensions
        patchSize                       % the size of the patch
        numelGrid                       % the number of elements in the grid
        numelPatch                      % the number of elements in the patch
        avgFilter                       % the filter to generate the "large-scale" flow
        idxPatch                        % the patch indices
        % and these are derived properties (defined from the ones above)
    end
    
    methods
        function obj = Scrambler(gridSize, patchDim, boundaryCondition)
        %% function obj = Scrambler(gridSize, patchDim, boundaryCondition)
        %
        % The class constructor.
        %
        % Arguments:
        %   * gridSize:  [M, N] or [M, N, P] the grid dimension;
        %   * patchDim: the ODD patch dimension - typically 3;
        %   * boundayCondition: 'replicate', 'symmetric' or 'circular' -- see
        %     help padarray
        %
        % Output: a SVDnoise class instance.
        %
        % Written by P. DERIAN 2017-01-26
        % Updated by P. DERIAN 2017-03-28: added 3d grid support.

            if nargin==3
                % user parameters
                obj.gridSize = gridSize;
                obj.patchDim = patchDim;
                obj.boundaryCondition = boundaryCondition;
                % remove singleton dimensions (see squeeze)
                obj.gridSize(obj.gridSize==1) = [];
                if ~isequal(obj.gridSize, gridSize)
                    warning('Scrambler: singleton dimensions removed in gridSize');
                end
            elseif nargin~=0
                error('Scrambler: 0 (default) or 3 (gridSize, patchDim, boundaryCondition) parameters expected by the contructor.');                
            end
            % the grid
            obj.numelGrid = prod(obj.gridSize);
            obj.nDimensions = numel(obj.gridSize); 
            % the patch/filter
            obj.patchSize = repmat(obj.patchDim, [1, obj.nDimensions]); % compute the patch size
            obj.numelPatch = obj.patchDim^obj.nDimensions;
            obj.avgFilter = ones(obj.patchSize)/obj.numelPatch;
            obj.idxPatch = obj.patch_indices(obj.gridSize, obj.patchDim, ...
                                             obj.boundaryCondition); 
        end
        
        function psobs = scramble_scalar(self, x, nObs, varargin)
        %% function psobs = scramble_scalar(self, x, nObs, [rshape,])
        %
        % Arguments:
        %   * x: the scalar field to scramble, a [M, N] 2d array;
        %   * nObs: the number of observations to generate. nObs=0 triggers
        %       random-less mode with nObs=self.patchSize.
        %   * [optional] rshape: if true (default), the output is a 3D array 
        %       of size [M, N, nObs], each "slice" is a pseudo-observation. If
        %       false, it is a 2D array of size [M*N, nObs], each colum is
        %       a pseudo-observation.
        %
        % Output: psobs the pseudo-observations generated by scrambling x.
        %
        % Written by P. DERIAN - 2017-06-06
        
            % the parameters
            rshape = parse_inputs(varargin);
            % the random obs indices
            if 0==nObs
                % [DEBUG] all patch values (no randomness)
                warning('Scrambler:scramble:debugMode', 'scramble() is being used in debug mode (with nObs=0), randomness disabled.\n');
                nObs = self.numelPatch;
                idxrand = repmat(1:self.numelPatch, [self.numelGrid, 1]);
            else
                % draw, for each numelGrid patch, nObs indices between 1 and numelPatch,
                % i.e. draw one point within the patch for each pseudo-observation of each patch.
                idxrand = randi(self.numelPatch, [self.numelGrid, nObs]);
            end
            % transform these as global coordinates in self.idxPatch
            % and from these, get the coordinates in the field.
            % Note: this is equivalent to
            %     idxrand(j,:) = self.idxPatch(j, idxrand(j,:));
            idxrand = bsxfun(@plus, idxrand*self.numelGrid, ((1-self.numelGrid):0)');
            idxrand = self.idxPatch(idxrand);
            % so we extract corresponding values and build pseudo observations
            psobs = zeros(self.numelGrid, nObs);
            psobs(1:self.numelGrid,:) = x(idxrand); 
            % reshape if requested
            if rshape
                psobs = reshape(psobs, [self.gridSize, nObs]);
            end
            return
            
            function rs = parse_inputs(v)
            %% function r = parse_inputs(v)
            % optional args parser for scramble_scalar()
            
                if isempty(v)
                    rs = true;
                elseif isscalar(v)
                    rs = v{1};
                else
                    error('Scrambler:scramble_sclar:invalidInputs', ...
                          'expecting at most 1 optional argument (reshape)');
                end
            end
        end
    end
    
    methods (Static)
        function Idp = patch_indices(gridSize, patchDim, boundaryCondition)
        %% Ip = patch_indices(gridSize, patchDim, boundaryCondition)
        %
        % In 2d, this function considers a [patchDim, patchDim] (square) patch sliding
        % over an image of size gridSize, with appropriate boundary conditions.
        % It returns a [prod(gridSize), patchDim^2] array where each row corresponds
        % to a grid point (patch center) and contains the global indices
        % (in a gridSize matrix) of the points in that patch. 
        % The 3d version is its natural extension in volume.
        %
        % Note: consider removing singleton dimensions in gridSiz prior to
        % calling this function for better efficiency.
        %
        % Arguments:
        %   * gridSize:  [M, N] or [M, N, P] the (volumic) image dimension;
        %   * patchDim: the ODD patch dimension;
        %   * boundayCondition: 'replicate', 'symmetric' or 'circular' -- see
        %         help padarray
        %
        % Output: Ip, the [prod(gridSize), patchDim^numel(gridSize)] array of global indices.
        %
        % Written by P. DERIAN 2016-10-25
        % Updated by P.DERIAN 2017-03-28: added 3d grid support. 

            % Check parameters
            if ~mod(patchDim, 2)
                error('patchIndices:ValueError', 'Expecting ODD patchDim (currently %d)', patchDim);
            end
            if ~strcmp(boundaryCondition, {'replicate', 'symmetric', 'circular'})
                error('patchIndices:ValueError', 'Expecting boundaryCondition to be "replicate", "symmetric" or "circular"');
            end
            % Dimensions
            patchLength = patchDim.^numel(gridSize); % number of points in a patch
            gridLength = prod(gridSize); % number of point in the entire grid
            % Create an array of global indices for a grid of size gridSize
            idx = 1:gridLength;
            % Reshape and padd with the correct boundary condition
            halfPatchDim = floor(patchDim/2);
            idxPadded = padarray(reshape(idx, gridSize), ...
                                 repmat(halfPatchDim, [1, numel(gridSize)]), ...
                                 boundaryCondition, 'both');
            % The array of patch indices
            Idp = zeros(gridLength, patchLength, 'uint32');
            % 2d case
            if 2==numel(gridSize)
                [im, in] = ind2sub(gridSize, idx);
                for j=idx
                    % patch indices j <=> (m, n)
                    m = im(j);
                    n = in(j);
                    % pixel index in padded array is 
                    %     np = n+halfPatchDim;
                    %     mp = m+halfPatchDim;
                    % so the patch bounds are:
                    %     np-halfPatchDim:np+halfPatchDim = n:n+patchDim-1
                    %     mp-halfPatchDim:mp+halfPatchDim = m:m+patchDim-1
                    % the indices of points within the patch are:
                    idxPatch = idxPadded(m:m+patchDim-1, n:n+patchDim-1);
                    Idp(j,:) = idxPatch(:);
                end
            % 3d case    
            elseif 3==numel(gridSize)
                [im, in, ip] = ind2sub(gridSize, idx);
                for j=idx
                    % patch indices j <=> (m, n, p)
                    m = im(j);
                    n = in(j);
                    p = ip(j);
                    % pixel index in padded array is 
                    %     np = n+halfPatchDim;
                    %     mp = m+halfPatchDim;
                    %     pp = p+halfPatchDim;
                    % so the patch bounds are:
                    %     np-halfPatchDim:np+halfPatchDim = n:n+patchDim-1
                    %     mp-halfPatchDim:mp+halfPatchDim = m:m+patchDim-1
                    %     pp-halfPatchDim:pp+halfPatchDim = p:p+patchDim-1
                    % the indices of points within the patch are:
                    idxPatch = idxPadded(m:m+patchDim-1, n:n+patchDim-1, p:p+patchDim-1);
                    Idp(j,:) = idxPatch(:);
                end
            else
                error('Scrambler:patch_indices:NotYetImplemented', 'Only 2d and 3d grid are currently supported.');
            end
        end
    end
    
end