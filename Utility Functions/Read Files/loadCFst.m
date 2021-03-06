function [Clck, CFileName,CFileNameFull] = loadCFst(Year,dayNum ,settings,FLAG_NO_LOAD)
%% loadCFst
% Find and parse IGS clock corrections.  The files to be parsed should
% already exist locally. 
%
% Required Inputs:
%  Year                - N-length vector of years of desired outputs
%  dayNum              - N-length vector of days of years of desired
%                        outputs
%  settings            - settings structure
%   .constellation     - Desired constellation indicator- can be:
%                        'GPS','GLO','GAL,'BDS','SBAS','MULTI'
%                        If 'MULTI' is chosen, then multiple constellations
%                        will be loaded, and settings.multiConst is
%                        necessary
%   .multiConst        - 1x5 boolean vector indicating desired
%                        constellations, with GPS-GLO-GAL-BDS-SBAS
%                        represented in the respective positions in the
%                        vector
%   .preciseProdDir    - Directory containing precise products- should be
%                        setup in initSettings with a config file
%   .gpsClkCenter      - 3 letter IGS Analysis Center for GPS corrections
%   .gloClkCenter      - 3 letter IGS Analysis Center for GLO corrections
%   .galClkCenter      - 3 letter IGS Analysis Center for GAL corrections
%   .GloPclkSource     - this should be set to 'MGEX'- this is old and bad
%
% Optional Inputs:
%  FLAG_NO_LOAD        - True = do not parse the file, just output the name
%                        and locaiton of the local file
%
% Outputs:
%  Clck                - Structure containing parsed precise clock
%                        information
%  CFileName           - Name of precise clock files parsed
%  CFileNameFull       - Name and directory of precise clock files parsed

% Adjust in case day number is 0
if dayNum == 0
    Year = Year-1;
    dayNum = YearDays(Year);
end

if nargin < 4
    FLAG_NO_LOAD = 0;
end
Clck = [];
if length(dayNum) > 1
    CFileName = {};
    CFileNameFull = {};
    for idx = 1:length(dayNum)
        [Clcki, CFileNamei,filenameFulli] = loadCFst(Year(idx),dayNum(idx),settings,FLAG_NO_LOAD);
        if ~FLAG_NO_LOAD
            if idx == 1
                Clck = Clcki;
            else
                Clck.Cepochs  = [Clck.Cepochs; Clcki.Cepochs];
                Clck.Cclk     = [Clck.Cclk Clcki.Cclk];
                Clck.Cclk_sig = [Clck.Cclk_sig Clcki.Cclk_sig];
            end
        end
        CFileName = [CFileName CFileNamei];
        CFileNameFull = [CFileNameFull filenameFulli];
    end
    
else
    
    jd = cal2jd(Year,1,0) + dayNum;
    gps_day = jd - cal2jd(1980,1,6);
    [yr,mn,dy]=jd2cal(jd);
    [dayNum,Year]=jd2doy(jd);
%     dayNum = jd2doy
    
    % Initialize output
    Clck = [];
    
    switch settings.constellation
        case 'GPS'
            switch settings.gpsClkCenter
                case 'IGS'
                    %precise clock file
                    CfileNameFormat = 'cod%04d%01d.clk_05s';
                    CpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                    
                    Clck.Cepochs = [];
                    Clck.Cclk = [];
                    Clck.Cclk_sig = [];
                    for jdx = 1:length(dayNum)
                        % get 30 second clock data from prior and current days
                        CFileName = sprintf(CfileNameFormat, floor((gps_day(jdx))/7), mod((gps_day(jdx)),7));
                        tmp = sprintf(CpathNameFormat, yr(jdx),dayNum);
                        if ~FLAG_NO_LOAD
                            [Cepochs, Cclk, Cclk_sig] = Read_GPS_05sec_CLK([tmp CFileName],1);
                            Cepochs = Cepochs + 86400*(gps_day(jdx));
                            
                            
                            % Remove known bad points-
                            % Bad clock data on 2015 day 182, PRN 9
                            idx = find(Cepochs > 1119824995 & Cepochs < 1119830395);
                            if ~isempty(idx)
                                Cclk(9,idx) = nan;
                            end
                            
                            Clck.Cepochs  = [ Clck.Cepochs; Cepochs];
                            Clck.Cclk     = [ Clck.Cclk Cclk];
                            Clck.Cclk_sig = [ Clck.Cclk_sig Cclk_sig];
                        end
                    end
                otherwise
                    %precise clock file
                    clkCenter = settings.gpsClkCenter;
                    
                    if strcmp(clkCenter,'com')
                        center3 = 'COD';
                    else
                        center3 = upper(clkCenter);
                    end
                    PpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                    pathStr = sprintf(PpathNameFormat, yr, dayNum);
                    
                    fname1 = [center3 '0MGXFIN_' num2str(Year,'%04d')  num2str(dayNum,'%03d')];
                    % check the directory for a file from that day
                    diri = dir(pathStr);
                    fileInd = find(~cellfun(@isempty,strfind({diri.name},fname1)) & ...
                        cellfun(@isempty,strfind({diri.name},'.gz')) & ~cellfun(@isempty,strfind({diri.name},'.CLK')) );
                    
                    if ~isempty(fileInd)
                        tmp = pathStr;
                        CFileName = diri(fileInd).name;
                    else
                        % if the RINEX3 filename is not available, check for the
                        % old one.
                        CfileNameFormat = [clkCenter '%04d%01d.clk'];
                        CpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                        CFileName = sprintf(CfileNameFormat, floor((gps_day)/7), mod((gps_day),7));
                        tmp = sprintf(CpathNameFormat, yr,dayNum);
                    end
                    
                    if ~FLAG_NO_LOAD
                        [Cepochs, Cclk, Cclk_sig] = Read_GLO_CLK([tmp CFileName],32,'G');
                        Cepochs = Cepochs + 86400*(gps_day);
                        
                        %                 if length(Cepochs) == 2880
                        %                    Cepochs = Cepochs(1:10:end);
                        %                    Cclk = Cclk(:,1:10:end);
                        %                    Cclk_sig = Cclk_sig(:,1:10:end);
                        %                 end
                        
                        Clck.Cepochs  = Cepochs;
                        Clck.Cclk     = Cclk;
                        Clck.Cclk_sig = Cclk_sig;
                    end
            end
            CFileNameFull = {[tmp CFileName]};
            CFileName = {CFileName};
        case 'GLO'
            switch settings.GloPclkSource
                case 'IGS'
                    %precise clock file
                    station = 'emx'; % emx/grm
                    CfileNameFormat = [station '%04d%01d.clk'];
                    CpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                    
                    % get 30 second clock data from prior and current days
                    CFileName = sprintf(CfileNameFormat, floor((gps_day)/7), mod((gps_day),7));
                    tmp = sprintf(CpathNameFormat, yr);
                    if ~FLAG_NO_LOAD
                        [Cepochs, Cclk, Cclk_sig] = Read_GLO_CLK([tmp CFileName],24);
                        Cepochs = Cepochs + 86400*(gps_day);
                        
                        Clck.Cepochs  = Cepochs;
                        Clck.Cclk     = Cclk;
                        Clck.Cclk_sig = Cclk_sig;
                    end
                case 'MGEX'
                    clkCenter = settings.gloClkCenter;
                    
                    PpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                    pathStr = sprintf(PpathNameFormat, yr,dayNum);
                    if strcmp(clkCenter,'com')
                        center3 = 'COD';
                    else
                        center3 = upper(clkCenter);
                    end
                    fname1 = [center3 '0MGXFIN_' num2str(Year,'%04d')  num2str(dayNum,'%03d')];
                    % check the directory for a file from that day
                    diri = dir(pathStr);
                    fileInd = find(~cellfun(@isempty,strfind({diri.name},fname1)) & cellfun(@isempty,strfind({diri.name},'.gz')) ...
                        & ~cellfun(@isempty,strfind({diri.name},'CLK'))  );
                    
                    if ~isempty(fileInd)
                        tmp = pathStr;
                        CFileName = diri(fileInd).name;
                    else
                        % if the RINEX3 filename is not available, check for the
                        % old one.
                        CfileNameFormat = [clkCenter '%04d%01d.clk'];
                        CpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                        CFileName = sprintf(CfileNameFormat, floor((gps_day)/7), mod((gps_day),7));
                        tmp = sprintf(CpathNameFormat, yr,dayNum);
                    end
                    
                    if ~FLAG_NO_LOAD
                        [Cepochs, Cclk, Cclk_sig] = Read_GLO_CLK([tmp CFileName],24,'R');
                        Cepochs = Cepochs + 86400*(gps_day);
                        
                        %                 if length(Cepochs) == 2880
                        %                    Cepochs = Cepochs(1:10:end);
                        %                    Cclk = Cclk(:,1:10:end);
                        %                    Cclk_sig = Cclk_sig(:,1:10:end);
                        %                 end
                        
                        Clck.Cepochs  = Cepochs;
                        Clck.Cclk     = Cclk;
                        Clck.Cclk_sig = Cclk_sig;
                        
                    end
            end
            CFileNameFull = {[tmp CFileName]};
            CFileName = {CFileName};
        case 'GAL'
            clkCenter = settings.galClkCenter;
            
            PpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
            pathStr = sprintf(PpathNameFormat, yr,dayNum);
            if strcmp(clkCenter,'com')
                center3 = 'COD';
            else
                center3 = upper(clkCenter);
            end
            fname1 = [center3 '0MGXFIN_' num2str(Year,'%04d')  num2str(dayNum,'%03d')];
            % check the directory for a file from that day
            diri = dir(pathStr);
            fileInd = find(~cellfun(@isempty,strfind({diri.name},fname1)) & cellfun(@isempty,strfind({diri.name},'.gz')) ...
                & ~cellfun(@isempty,strfind({diri.name},'CLK'))   );
            
            if ~isempty(fileInd)
                tmp = pathStr;
                CFileName = diri(fileInd).name;
            else
                % if the RINEX3 filename is not available, check for the
                % old one.
                CfileNameFormat = [clkCenter '%04d%01d.clk'];
                CpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                CFileName = sprintf(CfileNameFormat, floor((gps_day)/7), mod((gps_day),7));
                tmp = sprintf(CpathNameFormat, yr,dayNum);
            end
            
            if ~FLAG_NO_LOAD
                [Cepochs, Cclk, Cclk_sig] = Read_GLO_CLK([tmp CFileName],32,'E');
                Cepochs = Cepochs + 86400*(gps_day);
                
                Clck.Cepochs  = Cepochs;
                Clck.Cclk     = Cclk;
                Clck.Cclk_sig = Cclk_sig;
            end
            CFileNameFull = {[tmp CFileName]};
            CFileName = {CFileName};
        case 'BDS'
            clkCenter = settings.galClkCenter;
            
            PpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
            pathStr = sprintf(PpathNameFormat, yr,dayNum);
            if strcmp(clkCenter,'com')
                center3 = 'COD';
            else
                center3 = upper(clkCenter);
            end
            fname1 = [center3 '0MGXFIN_' num2str(Year,'%04d')  num2str(dayNum,'%03d')];
            % check the directory for a file from that day
            diri = dir(pathStr);
            fileInd = find(~cellfun(@isempty,strfind({diri.name},fname1)) & cellfun(@isempty,strfind({diri.name},'.gz')) ...
                & ~cellfun(@isempty,strfind({diri.name},'CLK'))   );
            
            if ~isempty(fileInd)
                tmp = pathStr;
                CFileName = diri(fileInd).name;
            else
                % if the RINEX3 filename is not available, check for the
                % old one.
                CfileNameFormat = [clkCenter '%04d%01d.clk'];
                CpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
                CFileName = sprintf(CfileNameFormat, floor((gps_day)/7), mod((gps_day),7));
                tmp = sprintf(CpathNameFormat, yr,dayNum);
            end
            
            if ~FLAG_NO_LOAD
                [Cepochs, Cclk, Cclk_sig] = Read_GLO_CLK([tmp CFileName],35,'C');
                Cepochs = Cepochs + 86400*(gps_day);
                
                Clck.Cepochs  = Cepochs;
                Clck.Cclk     = Cclk;
                Clck.Cclk_sig = Cclk_sig;
            end
            CFileNameFull = {[tmp CFileName]};
            CFileName = {CFileName};
%             %precise clock file
%             station = settings.bdsClkCenter;
%             CfileNameFormat = [station '%04d%01d.clk'];
%             CpathNameFormat =  [settings.preciseProdDir '/%d/%03d/'];
%             
%             % get 30 second clock data from prior and current days
%             CFileName = sprintf(CfileNameFormat, floor((gps_day)/7), mod((gps_day),7));
%             tmp = sprintf(CpathNameFormat, yr,dayNum);
%             
%             if ~FLAG_NO_LOAD
%                 [Cepochs, Cclk, Cclk_sig] = Read_GLO_CLK([tmp CFileName],35,'C');
%                 Cepochs = Cepochs + 86400*(gps_day);
%                 
%                 Clck.Cepochs  = Cepochs;
%                 Clck.Cclk     = Cclk;
%                 Clck.Cclk_sig = Cclk_sig;
%             end
%             CFileNameFull = {[tmp CFileName]};
%             CFileName = {CFileName};
        case 'MULTI'
            consts = {'GPS','GLO','GAL','BDS','SBAS'};
            settings2 = settings;
            
            tmp = [];
            CFileName = {};
            
            PRNs = [];
            constInds = [];
            CFileNameFull = {};
            
            for cdx = 1:length(settings.multiConst)
                if settings.multiConst(cdx)
                    settings2.constellation = consts{cdx};
                    
                    % Call yourself
                    [Cdatai,CFileNamei,CFileNameFulli] = loadCFst(Year, dayNum, settings2,FLAG_NO_LOAD);
                    
                    if ~FLAG_NO_LOAD
                        if isempty(PRNs)
                            PRNs = (1:size(Cdatai.Cclk,1))';
                            constInds = cdx*ones(size(PRNs));
                            
                            Clck.Cclk = Cdatai.Cclk;
                            Clck.Cepochs = Cdatai.Cepochs;
                            Clck.Cclk_sig = Cdatai.Cclk_sig;
                            
                        else
                            PRNs = [PRNs; (1:size(Cdatai.Cclk,1))'];
                            constInds = [constInds; cdx*ones(size(Cdatai.Cclk,1),1)];
                            
                            Clck.Cclk = [Clck.Cclk; Cdatai.Cclk];
                            Clck.Cclk_sig = [Clck.Cclk_sig; Cdatai.Cclk_sig];
                        end
                    end
                    
                    CFileName = [CFileName CFileNamei];
                    CFileNameFull = [CFileNameFull CFileNameFulli];
                end
            end
            Clck.PRNs = PRNs;
            Clck.constInds = constInds;
            
    end
        
end
end




