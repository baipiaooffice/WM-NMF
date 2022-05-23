function hh=gname(cases,line_handle)
%GNAME  Labels plotted points with their case names or case number.
%   GNAME(CASES) displays the graph window, puts up a cross-hair, and
%   waits for a mouse button or keyboard key to be pressed.  You can
%   position the cross-hair with the mouse and click once near each
%   point to see a label on that point.  Alternatively you can drag
%   a selection rectangle to label all points in the rectangle.  Click
%   with the right mouse button to remove labels.  When you are done,
%   press the enter or escape key to stop labeling.
%
%   CASES typically contains unique case names for each point, and is a
%   cell array of strings or a character matrix with each row representing
%   a name.  CASES can also be any grouping variable, which GNAME converts
%   to labels.
%
%   GNAME with no arguments labels each case with its case number.  It
%   also uses the case number as a label if the number of names in CASES
%   does not match the number of points on the line you select.
%
%   HH = GNAME(CASES,LINE_HANDLE) returns a vector of handles
%   to the text objects on the plot.  Use the scalar, LINE_HANDLE, to
%   specify a subset of the lines to label.  The default behavior
%   is to label all lines on the plot (except those with a line
%   style of '-', '--', or '-.' when there are multiple lines).
%
%   See also TEXT, GINPUT, RBBOX, GROUPINGVARIABLE.

%   Copyright 1993-2015 The MathWorks, Inc.

[az, el] = view;
if az ~= 0 || el ~= 90
    error(message('stats:gname:BadView'));
end
if (nargin < 1)
    cases = [];
    dolengthwng = false;  % no need to warn about bad CASES
else
    dolengthwng = true;   % warn if selected curve doesn't match CASES
    [idx,gn] = grp2idx(cases); % accept any grouping vector
    idx_nan = isnan(idx);
    if any(idx_nan)
        gn{end+1} = ' ';
        idx(idx_nan) = length(gn);
    end
    cases = gn(idx);
end
if (nargin < 2), line_handle = []; end
figh = gcf;

% Can't do this if another mouse mode is active
hManager = uigetmodemanager(figh);
if (~isempty(hManager.CurrentMode))
    error(message('stats:gname:ModeActive', get( hManager.CurrentMode, 'name' )))
end

a = findobj(figh, 'Type', 'axes');
if (length(a) < 2)
    h=gnamesub(dolengthwng,cases,line_handle);
else
    h = [];
    bigax = gca;
    
    % Disbale axestoolbar in gname
    currVis = bigax.Toolbar.Visible;
    bigax.Toolbar.Visible = 'off';
    
    set(figh,'CurrentAx',bigax)
    [x0,y0,x1,y1] = ginput0(1);
    while ~isempty(x0)
        % Invoke subroutine with current axes set properly
        [h0,dolengthwng] = gnamesub(dolengthwng,cases,line_handle,x0,y0,x1,y1);
        h = [h; h0(:)];
        % Get next mouse click
        set(figh,'CurrentAx',bigax)
        [x0,y0,x1,y1] = ginput0(1);
    end
    
    if ishghandle(figh) && ishghandle(bigax)
        set(figh,'CurrentAx',bigax)
        % Disbale axestoolbar in gname
        bigax.Toolbar.Visible = currVis;
    end
end

if nargout > 0
    hh = h(ishghandle(h));
end

% ----------------------------------
function [h,dolengthwng]=gnamesub(dolengthwng,cases,line_handle,x0,y0,x1,y1)
% If no line handles supplied, get lines that appear to be plots of
% data rather than fits.  (See the lsline function.)
h = [];
axesh = gca;
figh = gcf;

% If the current axes contains the result of a scatter() function call,
% obtain the collection of objects that correspond to the plotted points.
% The objects will be either of 'Scatter' type.
patches = [];
scatters = findobj(axesh,'Type','scatter');

% Get all (x,y) values that may be labeled
u = get(axesh, 'UserData');
specialgraph = 0;          % from a special plotting function?
if (iscell(u))
    if (strcmp(u{1}, 'gscatter'))
        specialgraph = 1;
    elseif (strcmp(u{1}, 'boxplot'))
        specialgraph = 2;
    elseif strcmp(u{1},'addedvarplot')
        specialgraph = 3;
    end
end

if isempty(line_handle) && isempty(patches) && isempty(scatters)
    line_handle = findobj(axesh,'Type','line');
    tmp = line_handle;
    for j=length(line_handle):-1:1
        style = get(line_handle(j),'LineStyle');
        if (strcmp(style,'-') || strcmp(style,'--') || strcmp(style,'-.'))
            line_handle(j) = [];
        end
        if specialgraph==3 && strcmp(style,':')
            line_handle(j) = []; % don't label confidence band
        end
    end
    if isempty(line_handle)
        line_handle = tmp;
    end
end

nlines = length(line_handle);
if iscell(cases)
    ncases = length(cases);
else
    ncases = size(cases,1);
end

if (specialgraph == 1)
    
    % If from the gscatter function, userdata has useful information
    xdat = u{2};
    ydat = u{3};
    n = size(xdat,1);
    nx = size(xdat,2);
    ny = size(ydat,2);
    if (nx>1)
        ydat = repmat(ydat,nx);
        xdat = xdat(:);
    elseif (ny>1)
        xdat = repmat(xdat,ny);
        ydat = ydat(:);
    end
    casenums = repmat((1:n)', max(nx,ny), 1);
    if (n == ncases), casenums = -casenums; end
    
elseif (specialgraph == 2)
    
    % From the boxplot function
    ydat = u{2};
    xdat = u{3};
    vert = u{4};
    if isempty(xdat)
        if size(ydat,2)==1
            xdat = ones(size(ydat));
        else
            xdat = repmat(1:size(ydat,2),size(ydat,1),1);
            ydat = ydat(:);
            xdat = xdat(:);
        end
    end
    if ~isequal(vert,1) % swap x/y for horizontal boxes
        tmp = xdat;
        xdat = ydat;
        ydat = tmp;
    end
    n = size(ydat,1);
    casenums = (1:n)';
    if (n == ncases), casenums = -casenums; end
    
elseif (nlines == 0)
    
    if isempty(scatters)
        % Currently, Scatter is the only plot type where
        % no lines is valid for gname().
        error(message('stats:gname:NoLine'));
    end
    xdat = [];
    ydat = [];
    for i=length(scatters):-1:1
        xdat = [xdat get(scatters(i),'XData')];
        ydat = [ydat get(scatters(i),'YData')];
    end
    ax = ancestor(scatters(1),'axes');
    [xdat, ydat] = matlab.graphics.internal.makeNumeric(ax,xdat,ydat);
    nx = length(xdat);
    if (nx == ncases)
        casenums = -1:-1:-nx;     % negative numbers to use values of cases
    else
        casenums = 1:nx;
    end
    
else
    
    xdat = get(line_handle,'XData');
    ydat = get(line_handle,'YData');
    ax = ancestor(line_handle,'axes');
    [xdat, ydat] = matlab.graphics.internal.makeNumeric(ax,xdat,ydat);
    if (nlines == 1)
        nx = length(xdat);
        if (nx == ncases)
            casenums = -(1:nx);
        else
            casenums = 1:nx;
        end
    else
        for j=1:nlines
            nx = length(xdat{j,1});
            if (nx == ncases)
                xdat{j,2} = -(1:nx);
            else
                xdat{j,2} = 1:nx;
            end
        end
        casenums = cat(2,xdat{:,2});
        xdat = cat(2,xdat{:,1});
        ydat = cat(2,ydat{:});
    end
    
end

% Prep axes for this operation
units = get(axesh,'defaulttextunits');
set(axesh,'defaulttextunits','data');
bmf = get(figh,'WindowButtonMotionFcn');
bdf = get(figh,'WindowButtonDownFcn');
set(figh,'WindowButtonMotionFcn','');
set(figh,'WindowButtonDownFcn','');
[xlim,ylim] = getLimits(axesh);
xrange = diff(xlim);
yrange = diff(ylim);

% Disable axestoolbar for gname
currVis = axesh.Toolbar.Visible;
axesh.Toolbar.Visible = 'off';

% Get click location, then place label at the appropriate point
if (nargin<4), [x0,y0,x1,y1] = ginput0(1); end
h = [];
while(~isempty(x0))
    rectangular = (x0 ~= x1) && (y0 ~= y1); % is this a rubber band selection?
    
    % Get distance from each symbol to selection (box or point)
    xd = max(0, (x0-xdat)/xrange) + max(0, (xdat-x1)/xrange) + ~isfinite(xdat);
    yd = max(0, (y0-ydat)/yrange) + max(0, (ydat-y1)/yrange) + ~isfinite(ydat);
    d = xd.*xd + yd.*yd;
    [d1,idx] = min(d);
    if (rectangular)        % select all points in rectangle
        idx = find(d<=0);
    elseif d1>2*0.05^2
        idx = [];            % select nothing if too far away
    end
    
    if ~isempty(idx)               % if any points were selected
        c0 = casenums(idx);             % get case numbers or labels
        if (c0 < 0)
            if iscell(cases)
                t0 = cases(-c0);
            else
                t0 = cases(-c0,:);
            end
        else
            t0 = strjust(int2str(c0(:)), 'left');
            if dolengthwng
                dolengthwng = false;
                warning(message('stats:gname:BadLength'));
            end
        end
        x0 = xdat(idx);                 % get coordinates
        y0 = ydat(idx);
        
        % Regular or ctrl/alt selection?
        adding = ~isequal(get(figh,'SelectionType'),'alt');
        if adding
            % Regular selection, add label to selected points
            h0 = text(x0, y0, t0, 'VerticalAlignment', 'baseline', 'Tag','gname');
            h = [h; h0(:)];
            f = [];
            if (~rectangular), f = find(d-d1 <= 1e-2*d1); end
            if (length(f) > 1)
                disp(getString(message('stats:gname:MultipleObs')));
                for j=1:length(f)
                    cj = casenums(f(j));
                    if (cj<0)
                        if iscell(cases)
                            txt = cases{-cj};
                        else
                            txt = cases(-cj,:);
                        end
                        fprintf('   %s',txt);
                    else
                        fprintf('   %d',cj);
                    end
                end
                fprintf('\n');
            end
        else
            % Remove label from selected points
            h0 = findobj(axesh,'Type','text','Tag','gname');
            hrem = [];
            for k=1:length(x0)
                hrem = [hrem; findall(h0,'flat','Position',[x0(k) y0(k) 0])];
            end
            delete(hrem);
        end
    end
    if (nargin>3), break; end
    [x0,y0,x1,y1] = ginput0(1);
end

h = h(ishghandle(h));
set(h,'units',units);
if ishghandle(axesh) && ishghandle(figh)
    set(axesh,'defaulttextunits',units);
    set(figh,'WindowButtonMotionFcn',bmf);
    set(figh,'WindowButtonDownFcn',bdf);
    
    % Restore axestoolbar
    axesh.Toolbar.Visible = currVis;
end

% ----- replacement for ginput/rbbox, gets correct axes
function [x0,y0,x1,y1] = ginput0(~)
x0 = [];y0 = [];x1 = [];y1 = [];
try
    [x,y,key] = ginput(1);
catch ME
    if isequal(ME.identifier,'MATLAB:ginput:FigureDeletionPause')
        return;
    else
        throwAsCaller(ME);
    end
end
if (isempty(x) || isequal(key, 27))
    return;
end
a0 = gca;
figh = gcf;
a = findobj(figh, 'Type', 'axes');
pt0 = get(a0, 'CurrentPoint');   % point at mouse down, current axes
pts0 = get(a, 'CurrentPoint');   % ditto, all axes
rbbox;
pt1 = get(a0, 'CurrentPoint');   % point at mouse up
pts1 = get(a, 'CurrentPoint');

% Make sure the current axes are set to the best choice
[xlim,ylim] = getLimits(a0);

if (  x<xlim(1) || x>xlim(2) || y<ylim(1) || y>ylim(2) ...
        || strcmp(get(a0,'Visible'),'off'))
    % Point is outside current axes, look for better ones
    if (length(a) > 1)
        for j=1:length(a)
            aa = a(j);
            if strcmp(get(aa,'Visible'), 'on')
                [xlim,ylim] = getLimits(aa);
                cp = pts0{j};
                xx = cp(1,1);
                yy = cp(1,2);
                if (xx>=xlim(1) && xx<=xlim(2) && yy>=ylim(1) && yy<=ylim(2))
                    % Update to these axes
                    set(figh, 'CurrentAxes', aa);
                    a0 = aa;
                    pt0 = cp;
                    pt1 = pts1{j};
                    break;
                end
            end
        end
    end
end

[xlim,ylim] = getLimits(a0);
x0 = max(xlim(1), min(pt0(1,1), pt1(1,1)));
y0 = max(ylim(1), min(pt0(1,2), pt1(1,2)));
x1 = min(xlim(2), max(pt0(1,1), pt1(1,1)));
y1 = min(ylim(2), max(pt0(1,2), pt1(1,2)));

function [xlim, ylim] = getLimits(ax)
xlim = get(ax, 'XLim');
ylim = get(ax, 'YLim');
[xlim,ylim] = matlab.graphics.internal.makeNumeric(ax,xlim,ylim);
