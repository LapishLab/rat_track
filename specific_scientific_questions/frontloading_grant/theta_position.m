function t = theta_position(t)
    for i=1:height(t)
        stream = t.stream{i};
        widow = 5; %Window time in s
        overlap= 4;
        is_ch = contains({stream.channels.channel_names}, 'CH');
        avg_ch = mean(stream.traces(:,is_ch), 2);
        avg_ch = zscore(avg_ch);
    
        F = [4 8 12];
        [~,~,T,P] = spectrogram(avg_ch,widow*1000,overlap*1000,F, 1000, 'psd');
        P = P(2,:);
        dB = 10*log10(P);
        T = T + stream.time(1);
    
        tracking = t.tracking{i};
        tracking.theta = interp1(T,dB,tracking.time, 'nearest', 'extrap');
        t.tracking{i} = tracking;
    end
end