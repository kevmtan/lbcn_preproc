function [badind, filtered_beh,spkevtind,spkts] = LBCN_filt_bad_trial_noisy(data_raw,fs,spk_thr,tapers,exwin,amp)
%   This function examines each epoched data and get the indicies of sharp spike/noise/artifact in a epoch.
%   Time stamps of identified samples and the [-exwin exwin] window will be
%   stored. These samples can be replaced as NAN when plotting.
%   Samples < 40 ms will be merged as one. Overlapping windows will also be merged.
%   Epochs with large variance, or more than 5 segments / > 600 samples identified will be marked as bad.
%   Input:  data_raw -- epoched data in columns.
%           spk_thr -- threshold to find spikes in a signal. Default 3.5.
%           Signal identified by this threshold will be examined.
%           atf_thr -- threshold to find artifacts in a signal. Default 5 times of the spk threshold.
%           Data with atf identified by this threshold would be excluded.
%           tapers -- put 1 to exclude sharp data points and put tapers in
%           the filtered data (> 16 Hz). Defalt 0. (dont use for now..)
%           exwin -- window length before and after the identified data
%           ponit to be stored. Defalt 15. 
%           amp -- define the shapness of the unwanted data segment.
%           Default 1/2, meaning the jump of the signal > half of its amplitude. 
%   Output: badind -- indicies of trials to exclude.
%           filtered_beh: data with spikes filtered.
%           spkevtind -- epochs with spikes identified.
%           spkts -- time stamps of spikes. These time stamps can be set to NaN for later plots.
%   Su Liu
%   suliu@stanford.edu.


if nargin < 3 || isempty(spk_thr)
    spk_thr = 4;
end
if nargin < 4 || isempty(tapers)
    tapers = 0;
end
if nargin < 5 || isempty(exwin)
    exwin = 10;
end
if nargin < 6 || isempty(amp)
    amp = 2/3;
end

[b,a] = butter(2,[2 70]/(fs/2));
[b2,a2] = butter(2,70/(fs/2),'high');
[b3,a3]=butter(2,20/(fs/2));
% [b4,a4]=butter(2,[16 200]/(fs/2));
tn = size(data_raw,2);
dn = size(data_raw,1);
badind = false(1,tn);
spkts = false(size(data_raw));
badind(sum(data_raw)==0) = 1;
badind(max(data_raw)>2000) = 1;
spkevtind = false(1,tn);
filtered_beh = zeros(size(data_raw));
df = filtfilt(b,a,data_raw);
dfn = data_norm(df,2);
vn = nan(1,tn);
vn(~badind) = var(dfn(:,~badind));
vnn = zeros(1,tn);
vnn(~badind) = data_norm(vn(~badind)',5);
if median(vnn)>0.98
    badind(vnn<0.8*median(vnn)) = 1;
end

df = filtfilt(b2,a2,data_raw);
vn = var(df);
vnn(~badind) = data_norm(vn(~badind)',5);
vnn(vnn==0)=nan;
if nanmedian(vnn)<0.01
    badind(vnn>8*nanmedian(vnn)) = 1;
end


% for j = find(~badind)
for j = 1:tn
    dat = data_raw(:,j);
    checkhf = filtfilt(b2,a2,dat);
    check = filtfilt(b,a,dat);
    [~,thhf] = get_threshold(checkhf,16,8,'std',spk_thr);
    [~,th2] = get_threshold(check,16,8,'std',18);
    peakind = find(diff(sign(diff(check))) ~= 0)+1;
    peakind2 = find(diff(sign(diff(checkhf))) ~= 0)+1;
    peaks = check(peakind);
    peaks2 = checkhf(peakind2);
    ind = peakind(diff(peaks)>1.2*max(abs(peaks)));
    %ind = peakind(abs(peaks) > th2);
    ind2 = peakind2(abs(peaks2) > thhf);
        match = false(1,length(ind));
        match2 = false(1,length(ind2))';
        for ii = 1:length(ind)
            if any(ismember(ind2,ind(ii)-20:ind(ii)+20))
                match(ii)=1;
                match2 = match2 + ismember(ind2,ind(ii)-20:ind(ii)+20);
            end
        end
        match2 = logical(match2);
        %ind = ind2(match2);
    if ~isempty(ind2)
        
        neg=peakind2(sign(peaks2)==-1);
        pos=peakind2(sign(peaks2)==1);
        
        group = abs(diff(ind2)) > 40;
        group = [1 group'];
        fg = find(group);
        gw = zeros(length(fg),2);
        try
            for kk = 1:length(fg)-1
                gw(kk,1) = fg(kk);
                gw(kk,2) = fg(kk+1)-1;
            end
        catch
        end
        gw(length(fg),1)=fg(end);
        gw(length(fg),2)=length(group);
        
        if any((gw(:,2)-gw(:,1))>20) 
            badind(j) = 1;
%             continue;  %% ***uncomment
        end
                
        sig=checkhf;
        sigsq=2*sig.*sig;
        
        ev=real(sqrt(filtfilt(b3,a3,sigsq)));
        lt=median(abs(ev(1:300)))*2.5;
        if max(abs(ev))>lt
            %         dd = (gw(:,2)-gw(:,1))>=1;
            %         if any(dd)
            for ii=1:size(gw,1)   %find(dd')
                
                if gw(ii,2) == gw(ii,1) && match2(gw(ii,1))
                    continue;
                end
                sig=checkhf;
                tind=ind2(gw(ii,1):gw(ii,2));
                fn = find(ismember(neg , tind));
                index=[min(fn)-3;min(fn)-2;min(fn)-1;max(fn)+1;max(fn)+2;max(fn)+3];
                try
                    tindn1 = neg(index);
                catch
                    continue;
                end
                mid1=median([abs(sig(neg(min(fn)))-sig(tindn1));abs(sig(neg(max(fn)))-sig(tindn1))]);
                fn = find(ismember(pos , tind));
                index=[min(fn)-3;min(fn)-2;min(fn)-1;max(fn)+1;max(fn)+2;max(fn)+3];
                try
                    tindn2 = pos(index);
                catch
                    continue;
                end
                mid2=median([abs(sig(pos(min(fn)))-sig(tindn2));abs(sig(pos(max(fn)))-sig(tindn2))]);
                pv = sig(tind);
                %maxdiff=[max(abs(diff(pv(sign(pv) == -1))));max(abs(diff(pv(sign(pv) == 1))))];
                middiff=[mid1;mid2];
                %peakdiff = [abs(diff(pv(sign(pv) == -1))) ; abs(diff(pv(sign(pv) == 1)))];
                %maxdiff=max(peakdiff);
                aa1=[median(abs(pv(pv<0)));median(pv(pv>0))]*amp;
                aa2=[max(abs(pv(pv<0)));max(pv(pv>0))]*amp;
                if (all(middiff(~isnan(middiff)) > aa2)&&(length(tind)<=6))...
                        ||( any(middiff(~isnan(middiff)) > aa2)...
                        && (match2(find(abs(pv)==max(abs(pv))))) &&(length(tind)<8))
                    
                elseif (any(middiff > aa1) && any(middiff < aa2)) 
                    ind2(gw(ii,1):gw(ii,2))=tind(abs(pv)==max(abs(pv)));
                    
                elseif any(match2(gw(ii,1):gw(ii,2))) 
                        %ind2(gw(ii,1):gw(ii,2))=tind(abs(pv)==max(abs(pv)));
                        ind2(gw(ii,1):gw(ii,2))=round(median(tind));
                else
                    ind2(gw(ii,1):gw(ii,2))=nan;
                end
            end
        end
    end
    %ind = ind(match);
    ind = unique(ind2(~isnan(ind2)));%(logical(match2));
    if ~isempty(ind)
        window = [ind-exwin ind+exwin];
        [~,A] = sort(window(:,1));
        window = window(A,:);
        overlap = find(window(2:end,:)-window(1:end-1,2)<0);
        window(overlap,2) = nan;
        window(overlap+1,1) = nan;
        window(isnan(window)) = [];
        window(window<=0) = 1;
        window(window>=dn) = dn;
        try
            window = reshape(window,length(window)/2,2);
        catch
        end
        if   size(window,1)<=10 ...
                && max(abs(dat)) < 2000 && sum(window(:,2)-window(:,1)) <= 600
            
            %             if size(window,1)==1
            %                     dnew=[dat(1:window(1));nan(window(1,2)-window(1,1)-1,1);dat(window(2):end)+dat(window(1))-dat(window(2))];
            %             elseif size(window,1)==2
            %                     dnew=[dat(1:window(1,1));...
            %                         nan(window(1,2)-window(1,1)-1,1);dat(window(1,2):window(2,1))+dat(window(1,1))-dat(window(1,2));...
            %                         nan(window(2,2)-window(2,1)-1,1);dat(window(2,2):end)+dat(window(1,1))-dat(window(1,2))+dat(window(2,1))-dat(window(2,2))];
            %             elseif size(window,1)==3
            %                 dnew=[dat(1:window(1,1));...
            %                     nan(window(1,2)-window(1,1)-1,1);dat(window(1,2):window(2,1))+dat(window(1,1))-dat(window(1,2));...
            %                     nan(window(2,2)-window(2,1)-1,1);dat(window(2,2):window(3,1))+dat(window(1,1))-dat(window(1,2))+dat(window(2,1))-dat(window(2,2));...
            %                     nan(window(3,2)-window(3,1)-1,1);dat(window(3,2):end)+dat(window(1,1))-dat(window(1,2))+dat(window(2,1))-dat(window(2,2))+dat(window(3,1))-dat(window(3,2))];
            %             end
            %            dat = dnew;
            if tapers
                %checkhf=filtfilt(b4,a4,dat);
                dnew = checkhf;
                intv=window(:,2)-window(:,1);
                %dnew = checkhf;
                dat = dnew;
                for jj = 1:length(intv)
                    try
                        seg1 = fliplr(dat((window(jj,1)-intv(jj)):window(jj,1)));
                        seg2 = fliplr(dat(window(jj,2):(window(jj,2)+intv(jj))));
                    catch
                        spkts(window(jj,1):window(jj,2),j)=1;
%                         badind(j) = 1;  %% comment
                        continue;
                    end
                    v = (1:-1/intv(jj):0);
                    v=v';
                    seg1 = seg1.*v;
                    
                    v = (0:1/intv(jj):1);
                    v=v';
                    seg2 = seg2.*v;
                    seg = seg1+seg2;
                    dnew(window(jj,1):window(jj,2))=seg;
                    try
                        dnew(window(jj,2)+1:window(jj+1,1))=dnew(window(jj,2)+1:window(jj+1,1));
                    catch
                        dnew(window(jj,2)+1:end)=dnew(window(jj,2)+1:end);
                    end
                end
                checkhf = dnew;
            else
                for k = 1:size(window,1)
                    spkts(window(k,1):window(k,2),j)=1;
%                     badind(j) = 1; % NEW
                end
%                     subplot 211;plot(check);subplot 212;
%                     plot(abs(ev));hold on;plot(sig);
%                     line([0 1151],[lt lt]);
%                    % plot(ind2(gw(ii,1):gw(ii,2)),peaks2(ismember(peakind2,ind2(gw(ii,1):gw(ii,2)))),'rx');
%                     line([0 1151],[thhf thhf],'color','c');
%                     spkdt=nan(size(checkhf));
%                     spkdt(spkts(:,j))=checkhf(spkts(:,j));
%                     plot(spkdt,'r','linewidth',1);hold off;
            end
            spkevtind(j) = 1;
        else
            badind(j) = 1;
        end
    end
    filtered_beh(:,j) = checkhf;
end
