% This test script runs all the examples.
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/testing/test_frambi.php

clearvars
close all

% load examples names
file_names = dir('../demos');
file_demo_idxs = find(cellfun(@(x) ~isempty(x) && x>0, strfind({file_names(:).name}, '.m')));

% run examples
for i=1:length(file_demo_idxs)
    [~,example_name,~] = fileparts(file_names(file_demo_idxs(i)).name);
    if contains(example_name, 'not_working'); continue; end
    if ~contains(example_name, 'frambi_'); continue; end
    fprintf('############################### \n')
    fprintf('## Running %s\n', example_name)
    feval(example_name)
    fprintf('############################### \n\n\n')
end
