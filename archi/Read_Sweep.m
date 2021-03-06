function [t,U,I] = Read_Sweep(time, DBH, CONTENTS, DURATION)
% Read_Sweep_mm reads bias and current data of CASSINI/RPWS/LP.
%
% Usage:
% In easiest case, just run 'Read_Sweep'. The specific time intervals are
% asked for and the data set will be stored in the 'base' workspace as:
%   t_sweep for time, U_sweep for bias voltage, and I_sweep for current.
% Altenatively, [t,U,I] = Read_Sweep_mm(time) returns data set instead.
% time should be in either epoch or in format of:
% [yyyy mm dd], [yyyy doy], [yyyy mm dd hh mm ss], and [yyyy doy hh mm ss].
% Give time interval in two colums e.g. [yyyy mm dd;yyyy mm dd]
%
% Michiko Morooka, IRFU/Uppsala, 2008.
%
% added algorithm to remove time spikes from data
% FIX_DATA function replaced by intersect command
% SweepMode function replaced with a simpler algorithm
% (commented as there is no need to fix double plateau values, saving ALL data)
% Oleg Shebanits, IRFU/Uppsala, 2012-02-07.
%
%
% WARNING!!! The code uses assignin('base', ...) to assign variables outside function.
% BUG(?): Can throw error for times without data.
% WARNING: Code assumes that it can either append to, or create file '../../Cassini_LP_DATA_Archive/LP_Swp_Clb/spikelog.mat' (hardcoded path).
% WARNING: Sets global variable "datapath".


global datapath %apppath

datapath = '../../Cassini_LP_DATA_Archive/';

% ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == =
% --- OPEN DBH ------------------------------------------------------------
if nargin<3
    if ~exist('CONTENTS','var')
        CONTENTS = [];
        DURATION = [];
    end
end
if nargin < 2
    if ~exist('DBH','var')
        %      DBH_name = input('DBH name    = titan.irfu.se. Input otherwise.: ');
        %      if isempty(DBH_name),
        DBH_name = 'titan.irfu.se';
        %      end
        %      DBH_port = input('DBH port no = 33.            Input otherwise.: ');
        %      if isempty(DBH_port),
        DBH_port = 33;
        %      end
        DBH = Connect2DBH(DBH_name,DBH_port); % Connect to ISDAT
    end
end

if DBH == 0, disp([DBH_name,':',DBH_port,' does not respond.']), return, end


if isempty(CONTENTS) || isempty(DURATION)
    error('Argument CONTENTS or DURATION is empty')
%    [CONTENTS,DURATION] = isGetContentLiteWrapper(DBH,'Cassini','','lp','','','','');
%    [CA.CONTENTS, CA.DURATION] = check_DURATION(CA.CONTENTS, CA.DURATION, 'interactive');    
end

% ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == =
% --- chose read time interval --------------------------------------------
if nargin<1
    st = timeinput('Start time?');
    et = timeinput('End   time?');
    if isempty(et), time = st;
    else            time = [st;et]; end
    clear st et
end

st=timeform2epoch(time(1,:));
if length(time(:,1))>1, et=timeform2epoch(time(end,:)); time = [st;et];
else            time = st; end

if ~exist('et','var')
    block = find(toepoch(CONTENTS) <= st & st <= toepoch(CONTENTS)+DURATION);
else
    % Assign st_block := The (index to) CONTENTS block beginning immediately before st.
    %        et_block := The (index to) CONTENTS block ending    immediately after  et (or the last available CONTENTS block if no such exists).
    st_block = find(toepoch(CONTENTS) <= st);
    if ~isempty(st_block)
        st_block = st_block(end);
    end
    et_block = find(et <= toepoch(CONTENTS)+DURATION);
    if isempty(et_block)
        et_block = size(CONTENTS, 1);    % Index to last row in CONTENTS.
    else
        et_block = et_block(1);
    end
    block = st_block:et_block;
end

if isempty(block)
    % TEMPORARY(?) ERROR CHECK.
    % Throw explicit error message for this since the following command will throw a less comprehensible error otherwise.
    % NOTE: toepoch refers to @spis:/usr/local/isdat/clients/APIs/matlab/matlib/toepoch.m which should probably not be
    % modified unilaterally. Should use irfu-matlab equivalent instead?!!
    error('There is not enough data to analyze.')
end
checkcont = toepoch(CONTENTS(block, :));
checkcont = find(checkcont >= st & checkcont <= et, 1); % Doesn't matter how many values in there, at least 1 is sufficient.
if isempty(checkcont)
    disp('No data in the time interval');
    t = []; U = []; I = [];
    assignin('base','t_sweep',t);
    assignin('base','U_sweep',U);
    assignin('base','I_sweep',I);
    return;
end


if isempty(block), disp('No data found'),
    if st>toepoch(CONTENTS(end,:)), disp(['Latest data: ',num2str(fix(CONTENTS(end,:)))]); end
    t = [];
    U = [];
    I = [];
    assignin('base','t_sweep',t);
    assignin('base','U_sweep',U);
    assignin('base','I_sweep',I);
    return
end
disp(fix(CONTENTS(block,:)))
% ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == =
% --- Read data one block by one block ------------------------------------
time_out = []; bias_out = []; current_out = [];
spikelog_U = [];
spikelog_I = [];


% tic;

% Iterate over ISDAT time intervals.
for ii = block(1):block(end)
    
    t_start = toepoch(CONTENTS(ii,:));
    dt = DURATION(ii);

    try
        %if dt == 260
        %     q=2;    % DEBUG
        %end
        [U_time,bias]    = ...
            isGetDataLite(DBH,t_start,dt,'Cassini','','lp','sphp','bias', '','' );
        [I_time,current] = ...
            isGetDataLite(DBH,t_start,dt,'Cassini','','lp','sphp','sweep','','' );
    catch
        DBH = Connect2DBH('titan.irfu.se', 33); % RE-Connect to ISDAT
        [U_time,bias]    = ...
            isGetDataLite(DBH,t_start,dt,'Cassini','','lp','sphp','bias', '','' );
        [I_time,current] = ...
            isGetDataLite(DBH,t_start,dt,'Cassini','','lp','sphp','sweep','','' );
    end

    if isempty(U_time), continue; end
    % == =Make sure there is a unique time with ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==
    % == =a unique current and bias value. ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==
    % ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == =
    
    %----- this tests for spikes in a time vector and removes the spiked data -----
    %----- /Oleg Shebanits, IRFU/Uppsala, 2012-02-07 -----
    
    % fixing U_time and bias
    difneg_indU = find(diff(U_time)<0); % find negative spikes ALL VALUES NEEDED DON'T ADD ",1" to FIND
    if ~isempty(difneg_indU) % if there are spikes at all...
        AnmU = [];
        for i = 1:length(difneg_indU)
            spike_end = find(U_time > U_time(difneg_indU(i))); % end of the spike to cut out
            if isempty(spike_end) % = the spike is in the end of time vector
                spike_end = length(U_time); % index of the last entry
            end
            AnmU = [AnmU difneg_indU(i)+1:spike_end(1)-1]; % indexes of spike values to cut out
        end
        spikelog_U = [spikelog_U; [U_time(AnmU) bias(AnmU)]]; % log the spiked values before they are cut
        U_time(AnmU) = []; % remove the spikes in time vector
        bias(AnmU) = []; % remove the corresponding entries in bias vector
    end
    
    % fixing I_time and current
    difneg_indI = find(diff(I_time)<0); % find negative spikes
    if ~isempty(difneg_indI) % if there are spikes at all...
        AnmI = [];
        for i = 1:length(difneg_indI)
            spike_end = find(I_time > I_time(difneg_indI(i))); % end of the spike to cut out
            if isempty(spike_end) % = the spike is in the end of time vector
                spike_end = length(I_time); % index of the last entry
            end
            AnmI = [AnmI difneg_indI(i)+1:spike_end(1)-1]; % indexes of spike values to cut out
        end
        spikelog_I = [spikelog_I; [I_time(AnmI) current(AnmI)]]; % log the spiked values before they are cut
        I_time(AnmI) = []; % remove the spikes in time vector
        current(AnmI) = []; % remove corresponding entries in current vector
    end
    %------------------------------------------------------------------------------
    
    
    [time3 indU indI] = intersect(U_time, I_time); % this is so awesome it also seems to remove entries with NaN in either U or I
    bias_out = [bias_out;bias(indU)];
    current_out = [current_out;current(indI)];
    clear indU indI;
    time_out = [time_out;time3];
    
end

if ~isempty(spikelog_U)
    disp(['bias data: time anomaly found, ' num2str(length(spikelog_U(:,1))) ' entries removed']);
    % save the spikes in U_bias in a logfile
    timelog = fromepoch(st);
    % generating variable name "spikelog_Ubias_YYYYDOY" and saving it in a .mat log
    Ulogvar = genvarname(sprintf('spikelog_Ubias_%4d%03d', timelog(1), date2doy(timelog(1:3))));
    eval([Ulogvar '= spikelog_U;']);
    if exist([datapath, 'LP_Swp_Clb/spikelog.mat'], 'file') == 2
        save([datapath, 'LP_Swp_Clb/spikelog.mat'], Ulogvar, '-append');
    else
        save([datapath, 'LP_Swp_Clb/spikelog.mat'], Ulogvar);
    end
    disp(['Anomaly saved in ' Ulogvar]);
    %fid1 = fopen('spikelog_U_bias.dat', 'a'); fprintf(fid1, '%6.6g %6.6g\n', spikelog_U); fclose(fid1);

end

if ~isempty(spikelog_I)
    disp(['current data: time anomaly found, ' num2str(length(spikelog_I(:,1))) ' entries removed']);
    % save the spikes in current in a logfile
    timelog = fromepoch(st);
    % generating variable name "spikelog_current_YYYYDOY" and saving it in a .mat log
    Ilogvar = genvarname(sprintf('spikelog_current_%4d%03d', timelog(1), date2doy(timelog(1:3))));
    eval([Ilogvar '= spikelog_I;']);
    if exist([datapath, 'LP_Swp_Clb/spikelog.mat'], 'file') == 2
        save([datapath, 'LP_Swp_Clb/spikelog.mat'], Ilogvar, '-append');
    else
        save([datapath, 'LP_Swp_Clb/spikelog.mat'], Ilogvar);
    end
    disp(['Anomaly saved in ' Ilogvar]);
    %fid2 = fopen('spikelog_current.dat', 'a'); fprintf(fid2, '%6.6g %6.6g\n', spikelog_I); fclose(fid2);
    
end

clear AnmI
clear AnmU





if isempty(time_out)
    disp('No data');
    t = []; U = []; I = [];
    assignin('base','t_sweep',t);
    assignin('base','U_sweep',U);
    assignin('base','I_sweep',I);
    return;
end



et = find(diff(time_out)>1); st = [1;et+1]; et = [et;length(time_out)]; % sets up indexes for start/end times for each sweep
if length(time) == 1
    pt = find(abs(time_out(st)-time) == min(abs(time_out(st)-time)));
    t_int = [st(pt):et(pt)];
    st = fromepoch(time_out(t_int(1))); et = fromepoch(time_out(t_int(end)));
    disp(sprintf('%04d.%02d.%02d %02d:%02d:%f - %f',[st et(end)]))
elseif length(time) == 2
    s_int = find(time_out(st) >= time(1));
    e_int = find(time_out(et) <= time(2));
    if isempty(s_int) || isempty(e_int)
        t = []; U = []; I = [];
        disp('No data in the given time interval');
        return;
    end
    
    s_int = s_int(1);
    st = st(s_int);
    e_int = e_int(end);
    et = et(e_int);
    t_int = [st:et];
end
t = time_out(t_int);
U = bias_out(t_int);
I = current_out(t_int);

% % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% % this section takes care of the double values wrt bias (plateus)
%
% et = find(diff(t)>1); st = [1;et+1]; et = [et;length(t)]; % st/et marks start/end time of each sweep
% tt = []; II = []; UU = [];
% for ii=1:length(st)
%     ind = [st(ii):et(ii)]; % index for each sweep
%     t_swp = t(ind); I_swp = I(ind); U_swp = U(ind); % temporary values
%     indp = find(diff(U_swp) ~= 0); indp = [indp; indp(end)+2]; % index last values of each plateu
%     tt = [tt; t_swp(indp)];
%     UU = [UU; U_swp(indp)];
%     II = [II; I_swp(indp)];
% end
%
% t = tt; U = UU; I = II; clear tt UU II
% % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%-=-=-=-=-calibration of the current
et = find(diff(t)>1); st = [1;et+1]; et = [et;length(t)]; % sets up indexes for start/end times for each sweep
for ii=1:length(st)
    I(st(ii):et(ii)) = Calibrate_archi(0, I(st(ii):et(ii)));
end
%-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-



if nargout<1,
    assignin('base','t_sweep',t);
    assignin('base','U_sweep',U);
    assignin('base','I_sweep',I);
    clear t U I
end

% toc;

return

% ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == =
% End of Main Function
% ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  ==  == =

