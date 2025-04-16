%   #Author: Piotr Majdak (2024)
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/testing/test_data_heeringa2024.php


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


list = data_heeringa2024('list');
info = data_heeringa2024('info','G201001'); % should load only the first batch
data = data_heeringa2024('data','G201001'); % should combine the three batches
data_heeringa2024('fig3');
data_heeringa2024('tab1');
data_heeringa2024('summary');
data_heeringa2024('fig4');  % should display unit 12
data_heeringa2024('fig4','G150717');  % should display unit 1
data_heeringa2024('fig4','G201001'); % should display unit 1, which is in batch 1
data_heeringa2024('fig4','G201001','unit',27); % should display unit 7, which is in batch 3
data_heeringa2024('fig5a'); % default animal as in the article
data_heeringa2024('fig5a', 'G230511'); % all units
data_heeringa2024('fig5a', 'G201001'); % all units (needs three batches)
data_heeringa2024('fig5b'); % no options here
data_heeringa2024('fig6');
data_heeringa2024('fig7');




