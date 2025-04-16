function fix_corrupt_test(input_file, output_file)
    try
        m = matfile(input_file, 'Writable', false);
        var_names = who(m);
        disp('Variables in file:');
        disp(var_names);
        
                result = struct();
        
                for i = 1:length(var_names)
            varname = var_names{i};
            try
                                if ~strcmp(varname, 'r_mean_downsampled')
                    result.(varname) = m.(varname);
                    disp(['  Loaded ' varname]);
                else
                                        try
                                                sz = size(m, varname);
                        disp(['  Variable size: ' num2str(sz)]);
                        
                                                data = zeros(sz);
                        chunk_size = 10;
                        for row = 1:chunk_size:sz(1)
                            end_row = min(row+chunk_size-1, sz(1));
                            try
                                data(row:end_row, :) = m.(varname)(row:end_row, :);
                                disp(['    Loaded rows ' num2str(row) '-' num2str(end_row)]);
                            catch
                                disp(['    Failed to load rows ' num2str(row) '-' num2str(end_row)]);
                            end
                        end
                        result.(varname) = data;
                    catch err
                        disp(['    Error with chunked loading: ' err.message]);
                                                result.(varname) = [];
                    end
                end
            catch err
                disp(['  Failed to load ' varname ': ' err.message]);
            end
        end
        
                save(output_file, '-struct', 'result');
        disp(['Saved recovered data to ' output_file]);
    catch err
        disp(['Process failed: ' err.message]);
    end
end
