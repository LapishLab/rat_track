function t = string2datetime(s)
    s = string(s);
    num_char = strlength(s);
    
    if all(num_char == 15)
        format = 'yyyyMMdd_HHmmss';
    elseif all(num_char == 22)
        format = 'yyyyMMdd_HHmmss_SSSSSS';
    else
        error('time string did not match expected character length.');
    end
    t = datetime(s, InputFormat=format);
end