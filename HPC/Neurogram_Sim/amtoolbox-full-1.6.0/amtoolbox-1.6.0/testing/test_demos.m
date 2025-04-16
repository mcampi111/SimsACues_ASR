x_AMT=dir(fullfile('..','demos','demo_*'));
for ii_AMT=1:length(x_AMT)
  disp(['**** ' x_AMT(ii_AMT).name]);
  [~,fn]=fileparts(x_AMT(ii_AMT).name);
  feval(fn);
end

%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/testing/test_demos.php


