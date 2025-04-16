amt_disp('This should be a new line as the first line.'); 
amt_disp('IF you see this, this is WRONG.','silent');
amt_disp(''); % start of volatile 
for ii=1:20
  amt_disp(['This progress will persist #' int2str(ii) ' of 20...'],'volatile');
  pause(0.1);
end
amt_disp([]); %end of volatile
amt_disp('This should be a new line and is also start for the new volatile.'); 
for ii=1:20
  amt_disp(['This progress will disappar: #' int2str(ii) ' of 20...'],'volatile');
  pause(0.1);
end
amt_disp('This line end and deletes the last volatile.'); %end of volatile
amt_disp('This line is a new line.'); %end of volatile
for ii=1:20
  amt_disp(['This progress will disappar and the function will finish: #' int2str(ii) ' of 20...'],'volatile');
  pause(0.1);
end
amt_disp();

%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/testing/test_amt_disp.php


