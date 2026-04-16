function out = sem(x)
    out = std(x, [], 'omitmissing') ./ sqrt(sum(~ismissing(x)));
end