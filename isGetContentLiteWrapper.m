%
% Wrapper around ISDAT's isGetContentLite to correct for bug(s) in the returned values.
% This function is meant to be used instead of isGetContentLite.
%
%
% ARGUMENTS AND RETURN VALUES
% ===========================
% All arguments are passed on directly to "isGetContentLite" and return values are passed on (returned) from
% "isGetContentLite". See "isGetContentLite".
%
%
% NOTE: There are at least two erroneous (too small) DURATION values. There might be many more
% (length(find(DURATION<1000)) == 125) so the code tries to correct for all ISDAT block durations < ~1 h and set them to
% ~1 h. I am uncertain if all other code will work with this.
%
% 
% Originally created 2017-02-0x by Erik P G Johansson, IRF Uppsala, Sweden.
%
function [start, dur] = isGetContentLiteWrapper( varargin )
% PROPOSAL: Manually set duration when it is suspiciously low.
%   PROPOSAL: Set it to ~3600 s.
%   PROPOSAL: Derive it from available data (measurements).
%   PROPOSAL: Derive it from the next 1 h block starting time.
%       CON: Can not handle the last block.
%       CON: Can not handle the absence of blocks (data gaps).
%
% PROPOSAL: Other code (at least Run_LP_Archi.m) contains checks for DURATION > 7200. Move to this function.
%   PRO: Shortens (removes duplication) and clarifies code.
%   NOTE: Original code (Run_LP_Archi.m) asks user for action. Can/should not keep.
%
% PROPOSAL: Call to "check_DURATION" here (not "GetContents")? Could possibly replace many (all?) calls to "check_DURATION" and equivalent code?
%

    [start, dur] = isGetContentLite(varargin{:});
    
    % Correct for what is apparently a bug in ISDAT
    % ---------------------------------------------
    % ISDAT returns a faulty duration value and claims that there is a "data period" for
    % 2017-01-23 17:00:00.2--17:02:46.7 when it really is ~1 h as usual.
    % Therefore replaces that faulty value.
    i = find(ismember(start(:, 1:5), [2017, 1, 23, 17, 0], 'rows'));   % NOTE: Does not check for the "seconds" value.
    if ~isempty(i)
        warning('Correcting for ISDAT DURATION value bug.')
        dur(i) = 3600-0.023;    % Approximate value from inspecting the start value after.
    end
    
    
    % Correct for what is apparently a bug in ISDAT - UNFINISHED
    % ----------------------------------------------------------
    % ISDAT returns a faulty duration value and claims that there is a "data period" for
    % 2017-05-09 (2017-129) 06:xx:xx.x--xxxxxxx (length 3.441230000000000e+02) when it really is ~1 h of data as usual.
    % Therefore replaces that faulty value.
    %i = find(ismember(CONTENTS(:,1:5), [2017, 05, 09, 06, 0], 'rows'));    % NOTE: Does not check for the "seconds" value. %Check minutes correct?
    %if ~isempty(i)
    %    warning('Correcting for ISDAT DURATION value bug.')
    %    dur(i) = 3600 - xxxxx;    % Approximate value from inspecting the start value after.
    %end
    

    %=======================================================================================
    % Force all ISDAT blocks to be reported as lasting at least one hour.
    % Exact values (limit, and forced value) from Michiko Morooka. Uncertain justification.
    %=======================================================================================
    i = find(dur < 3600-0.1);
    if ~isempty(i)
        warning('Correcting for presumed ISDAT DURATION value bug.')
        dur(i) = 3600-0.01;    % Approximate EXPECTED value.
    end

    
    
    % Deal with ISDAT bug which causes calls for ISDAT data to fail for certain longer time
    % intervals (possibly all time intervals which include certain samples).
    % 
    % NOTE: Does not check for the "seconds" value.
    [start, dur] = split_ISDAT_interval_2(start, dur, [2016, 12, 11, 20, 0], 60);
    [start, dur] = split_ISDAT_interval_2(start, dur, [2016, 12, 11, 21, 0], 60);
    [start, dur] = split_ISDAT_interval_2(start, dur, [2016, 12, 11, 22, 0], 60);
end



% NOTE: start_0 must not have all six fields.
function [start, dur] = split_ISDAT_interval_2(start, dur, start_0, N)
% PROPOSAL: Handle start_0 with multiple rows (to speed up code)?!!

    n = length(start_0);
    i = find(ismember(start(:, 1:n), start_0, 'rows'));
    
    if numel(i) == 1
        [start, dur] = split_ISDAT_interval(start, dur, i, N);
    elseif numel(i) == 0
        ;    % Do nothing
    else
        error('Found multiple matching ISDAT time intervals.')
    end
end
