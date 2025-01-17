function [idxbest, MedoidsBest, sumDbest, Dbest, Midx, info] = kmedoids(X, k, varargin)
%KMEDODIS K-medoids clustering.
%   IDX = KMEDOIDS(X, K) partitions the points in the N-by-P data matrix X
%   into K clusters.  This partition minimizes the sum, over all clusters,
%   of the within-cluster sums of point-to-cluster-medoid distances.  Rows
%   of X correspond to points, columns correspond to variables. KMEDOIDS
%   returns an N-by-1 vector IDX containing the cluster indices of each
%   point.  By default, KMEDOIDS uses squared
%   Euclidean distances.
%
%   KMEDOIDS treats NaNs as missing data, and ignores any rows of X that
%   contain NaNs.
%
%   [IDX, C] = KMEDOIDS(X, K) returns the K cluster medoid locations in
%   the K-by-P matrix C.
%
%   [IDX, C, SUMD] = KMEDOIDS(X, K) returns the within-cluster sums of
%   point-to-medoid distances in the K-by-1 vector SUMD.
%
%   [IDX, C, SUMD, D] = KMEDOIDS(X, K) returns distances from each point
%   to every medoid in the N-by-K matrix D.
%
%   [IDX, C, SUMD, D, MIDX] = KMEDOIDS(X, K) returns the indices MIDX such
%   that C = X(MIDX,:)
%
%   [IDX, C, SUMD, D, MIDX, INFO] = KMEDOIDS(X, K) returns a structure INFO
%   with information about how the algorithm was executed.
%
%   [ ... ] = KMEDOIDS(..., 'PARAM1',val1, 'PARAM2',val2, ...) specifies
%   optional parameter name/value pairs to control the iterative algorithm
%   used by KMEDOIDS.  Parameters are:
%
%   'Algorithm' - the algorithm to use to find the k-medoid clustering.
%   Choices are:
%       'pam' - Perform the swap phase from the original PAM algorithm in
%       [2]. This choice of algorithm is likely to give the highest quality
%       clustering solutions, but tends to take longer than the other
%       algorithm choices.
%
%       'small'  - Perform a K-means like algorithm to find K medoids. The
%       algorithm employs a variant of Lloyd's iterations based on [1].
%       This implementation has performance tweaks that differ from the
%       original description. It has an optional PAM like online phase that
%       improves cluster quality.
%
%       'clara' - From [2], CLARA repeatedly performs PAM on random subsets
%       of the data. The number of rows to sample is defined by a user
%       adjustable parameter samplesize. The algorithm performs a total
%       of 'replicates' such sample/searches. Performance can degrade for
%       large numbers of clusters, so for k>10, the large scale algorithm
%       is preferred.
%
%       'large'  - The large scale algorithm repeatedly performs searches
%       using a k-means like update, similar to the small scale algorithm;
%       however, only a random sample of cluster members are examined
%       during each iteration. The user adjustable parameter,
%       percentneighbor, controls the number of neighbors to examine. If
%       percentneighbor parameters are examined without finding an
%       improvement, then the algorithm terminates the local search. It has
%       an optional PAM like online phase that improves cluster quality.
%       The algorithm performs a total of 'replicates' times before
%       terminating. The best found is returned to the user.
%
%   The algorithm chosen by default depends on the size of X:
%       - If the number of rows of X is less than 3000, PAM is chosen. 
%       - If the number of rows is between 3000 and 10000, small is chosen. 
%       - For all other cases, large is chosen.
%   These defaults are chosen to give a reasonable balance between the time
%   to run the algorithm and the quality of the resulting solution. The
%   best choice will vary depending on the needs of the user and the data
%   being clustered.
%
%   'OnlinePhase' - A flag indicating whether to perform a PAM like
%   online phase in the small and large algorithms. The online phase occurs
%   after the Lloyd iterations complete. This tends to improve the quality
%   of solutions generated by both of these algorithms. Total runtime
%   tends to increase, but the increase typically is less than one
%   iteration of PAM. Flag can be 'on' (default) or 'off'.
%
%   'Distance' - Choices are:
%
%       'sqEuclidean'	-   Squared Euclidean distance (default).
%       'euclidean'     -   Euclidean distance.
%       'seuclidean'	-   Standardized Euclidean distance. Each
%                           coordinate difference between rows in X is
%                           scaled by dividing by the corresponding element
%                           of the standard deviation computed from X,
%                           S=nanstd(X).
%       'cityblock'     -   City block metric.
%       'minkowski'     -   Minkowski distance, with exponent 2. 
%       'chebychev'     -   Chebychev distance (maximum coordinate difference).
%       'mahalanobis'	-   Mahalanobis distance, using the sample 
%                       -   covariance of X as computed by nancov. 
%       'cosine'        -   One minus the cosine of the included angle 
%                       -   between points (treated as vectors).
%       'correlation'	-   One minus the sample correlation between points
%                       -   (treated as sequences of values).
%       'spearman'      -   One minus the sample Spearman's rank correlation
%                       -   between observations, treated as sequences of values.
%       'hamming'       -   Hamming distance, the percentage of coordinates 
%                       -   that differ.
%       'jaccard'       -   One minus the Jaccard coefficient, the percentage
%                       -   of nonzero coordinates that differ.
%       function        -   A distance function specified using @:
%           A distance function must be of the form
%           function D2 = distfun(ZI, ZJ)
%           taking as arguments a 1-by-n vector ZI containing a single
%           observation from X or Y, an m2-by-n matrix ZJ containing
%           multiple observations from X or Y, and returning an m2-by-1
%           vector of distances D2, whose Jth element is the distance
%           between the observations ZI and ZJ(J,:). If your data is not
%           sparse, generally it is faster to use a built-in distance than
%           to use a function handle.
%
%   'Options' - Options for the iterative algorithm used to minimize the
%       fitting criterion, as created by STATSET.  Choices of STATSET
%       parameters are:
%
%          'Display'       - Level of display output.  Choices are 'off', (the
%                            default), 'iter', and 'final'.
%          'MaxIter'       - Maximum number of iterations allowed.  Default is 100.
%          'UseParallel'   - If true and if a parpool of the Parallel Computing
%                            Toolbox is open, compute in parallel. If the
%                            Parallel Computing Toolbox is not installed, or a
%                            parpool is not open, computation occurs in serial
%                            mode. Default is false, meaning serial
%                            computation.
%          'UseSubstreams' - Set to true to compute in parallel in a
%                            reproducible fashion. Default is false. To
%                            compute reproducibly, set Streams to a type
%                            allowing substreams: 'mlfg6331_64' or
%                            'mrg32k3a'.
%          'Streams'       - These fields specify whether to perform clustering
%                            from multiple 'Start' values in parallel, and how
%                            to use random numbers when generating the starting
%                            points. For information on these fields see
%                            PARALLELSTATS. 
%                            NOTE: If 'UseParallel' is TRUE and
%                            'UseSubstreams' is FALSE, then the length of
%                            'Streams' must equal the number of workers
%                            used by KMEDOIDS.  If a parallel pool is
%                            already open, this is the size of the parallel
%                            pool.  If a parallel pool is not already open,
%                            then MATLAB may try to open a pool for you
%                            (depending on your installation and
%                            preferences). To ensure more predictable
%                            results, it is best to use the PARPOOL command
%                            and explicitly create a parallel pool prior to
%                            invoking KMEDOIDS with 'UseParallel' set to
%                            TRUE.
%
%   'Replicates'    - Number of times to repeat the clustering, each with a
%      new set of initial centroids.  A positive integer, default depends
%      on choice of algorithm. For 'pam' and 'small' the default is 1. For 'clara'
%      default is 5. For 'large' default is 3.
%
%   'NumSamples - The number of samples to take from the data when
%      executing the 'clara' algorithm. The algorithm randomly samples
%      numsample rows from the data and perform the 'pam' algorithm on this
%      subset. The default is 40 + 2*k.
%
%   'PercentNeighbors' - The percent of the dataset to examine using the
%      large algorithm. If percentneighbors*size(X,1) candidate changes for
%      the medoids are examined with no improvement of the within cluster
%      medoid to point sum of distances then the algorithm terminates. The
%      value of this parameter can be set in (0,1), where
%         - a value closer to 1 tends to give higher quality solutions,
%           but the algorithm takes longer to run.
%         - a value closer to 0 tends to give lower quality solutions,
%           but finishes faster. 
%         - The default is .001.
%
%   'Start' - Method used to choose initial cluster medoid positions,
%      sometimes known as "seeds".  Choices are:
%          'plus'    - The Default. Select K observations from X according
%                      to the k-means++ algorithm: the first cluster center
%                      is chosen uniformly at random from X, after which
%                      each subsequent cluster center is chosen randomly
%                      from the remaining data points with probability
%                      proportional to its distance from the point�s
%                      closest existing cluster center.
%          'sample'  - Select K observations from X at random.
%          'cluster' - Perform preliminary clustering phase on random 10%
%                      subsample of X.  This preliminary phase is itself
%                      initialized using 'sample'.
%           matrix   - A K-by-P matrix of starting locations.  In this case,
%                      you can pass in [] for K, and KMEDOIDS infers K from
%                      the first dimension of the matrix.  You can also
%                      supply a 3D array, implying a value for 'replicates'
%                      from the array's third dimension.
%
%   Example:
%
%       X = [randn(20,2)+ones(20,2); randn(20,2)-ones(20,2)];
%       opts = statset('Display','iter');
%       [idx, meds] = kmedoids(X, 2, 'Distance','city', 'Algorithm','small',...
%                             'Replicates',5, 'Options',opts);
%       plot(X(idx==1,1),X(idx==1,2),'r.', ...
%            X(idx==2,1),X(idx==2,2),'b.', meds(:,1),meds(:,2),'kx');
%
%   See also CLUSTERDATA, KMEANS, LINKAGE, SILHOUETTE.
%
% References:
%
% [1] Park, Hae-Sang, and Chi-Hyuck Jun. "A simple and fast algorithm for 
%     K-medoids clustering." Expert Systems with Applications 36.2 (2009): 3336-3341.
% [2] Kaufman, Leonard, and Peter J. Rousseeuw. Finding groups in data: an 
%     introduction to cluster analysis. Vol. 344. John Wiley & Sons, 2009.

% Copyright MathWorks 2014


if nargin > 2
    [varargin{:}] = convertStringsToChars(varargin{:});
end

if nargin < 2
    error(message('stats:kmedoids:TooFewInputs'));
end

wasnan = any(isnan(X),2);
hadNaNs = any(wasnan);
if hadNaNs
    warning(message('stats:kmedoids:MissingDataRemoved'));
    X = X(~wasnan,:);
end

% n points in p dimensional space
[n, p] = size(X);

pnames = {'algorithm'   'distance'  'start' 'replicates'  'percentneighbors' 'numsamples' 'onlinephase' 'options'};
dflts =  {[]           'sqeuclidean' 'plus'          []      []       []    'on'  []};
[algorithm, distance,start,reps,pneighbors,numsamples,onlinePhase,options] ...
    = internal.stats.parseArgs(pnames, dflts, varargin{:});

% the distance object does more aggressive matching, change the input distance to
% the fully qualified name of the distance
if ischar(distance)
    distNames = {'euclidean'; 'seuclidean'; 'sqeuclidean'; 'cityblock'; 'chebychev'; ...
        'mahalanobis'; 'minkowski'; 'cosine'; 'correlation'; ...
        'spearman'; 'hamming'; 'jaccard'};
    distance = internal.stats.getParamVal(distance,distNames,'''Distance''');    
elseif ~isa(distance,'function_handle')
    error(message('stats:kmedoids:BadDistance')); 
end

% move onlinePhase to a common form
if ~(islogical(onlinePhase) || any(strcmpi(onlinePhase,{'on','off'})))
    error(message('stats:kmedoids:BadOnlinePhase'));
else
    % convert online phase to logical if it's a character array.
    if ischar(onlinePhase)
        onlinePhase = strcmpi(onlinePhase,'on');
    end
end

% initialize dist object
distObj = internal.stats.kmedoidsDistObj(X,distance);

initialMedoids = []; % used for passing
if ischar(start)
    startNames = {'sample','cluster','plus','kmeans++'};
    j = find(strncmpi(start,startNames,length(start)));
    if length(j) > 1
        error(message('stats:kmedoids:AmbiguousStart', start));
    elseif isempty(j)
        error(message('stats:kmedoids:UnknownStart', start));
    elseif isempty(k)
        error(message('stats:kmedoids:MissingK'));
    end
    start = startNames{j};
elseif isnumeric(start)
    initialMedoids = start;
    start = 'numeric';
    if isempty(k)
        k = size(initialMedoids,1);
    elseif k ~= size(initialMedoids,1);
        error(message('stats:kmedoids:StartBadRowSize'));
    elseif size(initialMedoids,2) ~= p
        error(message('stats:kmedoids:StartBadColumnSize'));
    else
        % check rows exist in X
        for iter = 1:size(initialMedoids,3)
            if ~all(ismember(initialMedoids(:,:,iter),X,'rows'))
                error(message('stats:kmedoids:StartBadValue'))
            end
        end
    end
    if isempty(reps)
        reps = size(initialMedoids,3);
    elseif reps ~= size(initialMedoids,3);
        error(message('stats:kmedoids:StartBadThirdDimSize'));
    end
    
else
    error(message('stats:kmedoids:InvalidStart'));
end

options = statset(statset('kmedoids'), options);

display = find(strncmpi(options.Display, {'off','final','iter'},...
    length(options.Display))) - 1;

if ~(isscalar(k) && isnumeric(k) && isreal(k) && k > 0 && (round(k)==k))
    error(message('stats:kmedoids:InvalidK'));
    % elseif k == 1
    % this special case works automatically
elseif n < k
    error(message('stats:kmedoids:TooManyClusters'));
end

% if algorithm is not defined by user, determine what to use
if isempty(algorithm)
    algorithm = internal.stats.kmedoidsDetermineAlgorithm(X,k);
end

% validate large algorithm options
if ~strcmp(algorithm,'large') && ~isempty(pneighbors)
    warning(message('stats:kmedoids:percentneighbors',algorithm));
elseif isempty(pneighbors)
    % set default
    pneighbors = .001;
elseif ~isscalar(pneighbors) || ~isnumeric(pneighbors) || (~(pneighbors<=1) || ~(pneighbors> 0))
    error(message('stats:kmedoids:percentneighborstype'));
end

% validate clara algorithm options
if ~(strcmp(algorithm,'clara')) && ~isempty(numsamples)
    warning(message('stats:kmedoids:numsamples',algorithm));
elseif isempty(numsamples)
    % set default
    numsamples = 40 + 2*k;
elseif ~isscalar(numsamples) || ~isnumeric(numsamples) || (~(numsamples> 0) || (uint64(numsamples) ~= numsamples))
    error(message('stats:kmedoids:numsamplestype'));
end

if isempty(reps)
    switch algorithm
        case 'clara'
            reps = 5;
        case 'large'
            reps = 2;
        otherwise
            reps = 1;
    end
end

% validate reps
if ~isscalar(reps) || reps<1 || reps==inf || (uint64(reps) ~= reps)
    error(message('stats:kmedoids:ReplicatesType'));
end

[useParallel, RNGscheme, poolsz] = ...
    internal.stats.parallel.processParallelAndStreamOptions(options,true);

usePool = useParallel && poolsz>0;

% Define the function that performs one iteration of the
% loop inside smartFor

initialize = initialFunc(start,distObj,initialMedoids);
oneRun = loopBody(algorithm,initialize,X,k,distObj,pneighbors,numsamples,options,display,usePool,onlinePhase);

if usePool
    % If the user is running on a parallel pool, each worker generates
    % a separate periodic report.  Before starting the loop,
    % seed the parallel pool so that each worker has an
    % identifying label (eg, index) for its report.
    internal.stats.parallel.distributeToPool( ...
        'workerID', num2cell(1:poolsz) );
end

% Prepare for in-progress
if display > 1 % 'iter' or 'final'
    
    % Periodic reports behave differently in parallel than they do
    % in serial computation (which is the baseline).
    % We advise the user of the difference.
    
    if usePool && display == 2 % 'iter' only
        warning(message('stats:kmedoids:displayParallel2'));
        
        switch algorithm
            case 'pam'
                fprintf('    worker\t   rep\t    iter\t         sum\n');
            case 'clara'
                fprintf('    worker\t   rep\t         sum\n');
            otherwise
                fprintf('    worker\t   rep\t    iter\t     num\t         sum\n');
                
        end
    else
        if useParallel
            warning(message('stats:kmedoids:displayParallel'));
        end
        if display == 2 % 'iter' only
            switch algorithm
                case 'pam'
                    fprintf('   rep\t    iter\t         sum\n');
                case 'clara'
                    fprintf('   rep\t         sum\n');
                otherwise
                    fprintf('   rep\t    iter\t   num\t         sum\n');
            end
        end
    end
end


% Perform K-Medoids replicates on separate workers.
ClusterBest = internal.stats.parallel.smartForReduce(...
    reps, oneRun, useParallel, RNGscheme, 'argmin');

% Extract the best solution
idxbest = ClusterBest{5};
MedoidsBest = ClusterBest{6};
sumDbest = ClusterBest{3};
totsumDbest = ClusterBest{1};
if nargout > 3
    Dbest = ClusterBest{7}';
end
if nargout > 4
    Midx = ClusterBest{8};
end
if nargout > 5
% build info struct
    info = struct('algorithm',algorithm,'start',start,'distance',distance,'iterations',ClusterBest{4},'bestReplicate',ClusterBest{2});
end
if display > 0 % 'final' or 'iter'
    fprintf('%s\n',getString(message('stats:kmedoids:FinalSumOfDistances',sprintf('%g',totsumDbest))));
end

if hadNaNs
    idxbest = statinsertnan(wasnan, idxbest);
end

end

function fcn = initialFunc(start,distObj,statedValues)
switch start
    case 'sample'
        fcn = @sample;
    case 'cluster'
        fcn = @cluster;
    case 'plus'
        fcn = @kplus;
    case 'numeric'
        fcn = @list;
end

    function [initialMedoids, index] = sample(X,k,S,~)
        [initialMedoids, index] = datasample(S,X,k,1,'Replace',false);
        index = index(:);
        if issparse(initialMedoids)
            initialMedoids = full(initialMedoids);
        end
    end

    function [initialMedoids, index] = cluster(X,k,S,~)
        sampleInds = randsample(S,size(X,1),ceil(size(X,1)*.1));
        Xsample = X(sampleInds,:);
        [~, initialMedoids, ~, ~, indexOfSample] = kmedoids(Xsample,k,'distance',distObj.distance,'replicates',1);
        index = sampleInds(indexOfSample);
        if issparse(initialMedoids)
            initialMedoids = full(initialMedoids);
        end
    end

    function [initialMedoids, index] = kplus(X,k,S,~)
        % this is adapted from k means
        distfun = @(varargin) distObj.pdist2(varargin{:});

        % Select the first seed by sampling uniformly at random
        index = zeros(k,1);
        [initialMedoids(1,:), index(1)] = datasample(S,X,1,1);
        minDist = inf(size(X,1),1);
        % Select the rest of the seeds by a probabilistic model
        for ii = 2:k
            minDist = min(minDist,distfun(X,initialMedoids(ii-1,:)));
            denominator = sum(minDist);
            if denominator==0 || denominator==Inf
                [initialMedoids(ii:k,:), index(ii:k)] = datasample(S,X,k-ii+1,1,'Replace',false);
                break;
            end
            sampleProbability = minDist/denominator;
            [initialMedoids(ii,:), index(ii)] = datasample(S,X,1,1,'Replace',false,...
                'Weights',sampleProbability);
        end
        
        if issparse(initialMedoids)
            initialMedoids = full(initialMedoids);
        end
    end

    function [initialMedoids, index] = list(X,k,S,rep)
        initialMedoids = statedValues(:,:,rep);
        
        % statedValues is a set of rows out of X, possibly non-unique, we
        % need to know the index, such that initialMedoids = X(index,:); so
        % we use intersect to derive index.
        [validation,~,index] = intersect(initialMedoids,X,'rows','stable'); %#ok<ASGLU>

        if size(index,1) ~= k
            % non-unique rows exist, fill the rest with random samples
            ii = size(index,1) + 1;
            [initialMedoids(ii:k,:),index(ii:k)] = datasample(S,X,k-ii+1,1,'Replace',false);
            warning(message('stats:kmedoids:NonUniqueStart',ii-1,k-ii+1))
        end
    end

end

function fcnHandle = loopBody(algorithm,initialize,X,k,distObj,pneighbors,numsamples,options,display,usePool,onlinePhase)

maxIterations = options.MaxIter;

% determine algorithm, case insensitive
% no partial matching for undocumented controls on small algorithm
specialCaseSmall = find(strcmpi(algorithm,{'smallprecalculated','smallnoprecalculated'}), 1);
if ~isempty(specialCaseSmall)
    algNumber = find(strcmpi(algorithm,{'smallprecalculated','smallnoprecalculated'}));
    algNumber = algNumber + 990;
else
    algNumber = find(strncmpi(algorithm,{'small','pam','clara','large'},length(algorithm)));
    if isempty(algNumber)
        error(message('stats:kmedoids:UnknownAlgorithm'));
    end
    if length(algNumber)>1
        error(message('stats:kmedoids:AmbiguousAlgorithm',algorithm));
    end
end

switch algNumber
    case 1
        if size(X,1) < 1500
            % we're in the situation where it's better to precalculate the
            % entire distance matrix
            xDist = precalcDistance(X,distObj);
            
            fcnHandle = @(rep,S) internal.stats.kmedoidsSmallPrecalculated(rep,S,X,k,distObj,initialize,maxIterations,xDist,display,usePool,onlinePhase);
        else
            fcnHandle = @(rep,S) internal.stats.kmedoidsSmall(rep,S,X,k,distObj,initialize,maxIterations,display,usePool,onlinePhase);
        end
        
    case 2
            xDist = precalcDistance(X,distObj);
            fcnHandle = @(rep,S) internal.stats.kmedoidsPAM(rep,S,X,k,distObj,initialize,maxIterations,xDist,display,usePool);
            
    case 3
        fcnHandle = @(rep,S) internal.stats.kmedoidsClara(rep,S,X,k,distObj,numsamples,initialize,options,display,usePool);
        
    case 4
        fcnHandle = @(rep,S) internal.stats.kmedoidsLarge(rep,S,X,k,distObj,pneighbors,initialize,maxIterations,display,usePool,onlinePhase);
        
    case 991
        % force the small precalculated path
        % This code path should not be called directly by users and may be
        % removed or changed in a future release.
            xDist = precalcDistance(X,distObj);
            fcnHandle = @(rep,S) internal.stats.kmedoidsSmallPrecalculated(rep,S,X,k,distObj,initialize,maxIterations,xDist,display,usePool,onlinePhase);
            
    case 992
        % force the small algorithm with no precalculated distance
        % This code path should not be called directly by users and may be
        % removed or changed in a future release.
            fcnHandle = @(rep,S) internal.stats.kmedoidsSmall(rep,S,X,k,distObj,initialize,maxIterations,display,usePool,onlinePhase);
    otherwise

end

end

function xDist = precalcDistance(X,distObj)
% internal utility for precalculated small algorithm
distVec = distObj.pdist(X);
xDist = zeros(size(X,1));
xDist(tril(true(size(X,1)),-1)) = distVec; % similar to generating squareform

end
