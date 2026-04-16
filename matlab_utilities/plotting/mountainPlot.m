function mountainPlot(dataVector)
[f,x] = ecdf(dataVector); %Compute empirical cumulative distribution function 
f(f>0.5) = 1 - f(f>0.5); %For all cdf values above 0.5 (median) fold back down to 0
plot(x,f)
end