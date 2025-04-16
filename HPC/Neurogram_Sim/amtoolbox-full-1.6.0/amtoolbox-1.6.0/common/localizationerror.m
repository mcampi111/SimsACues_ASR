function [varargout] = localizationerror(m,varargin)
%localizationerror Compute psychoacoustic performance parameters from a sound localization experiment
%   Usage: [accL, precL, accP, precP, querr] = localizationerror(m)
%          [res, meta, par] = localizationerror(m,errorflag)
%          [res, meta] = localizationerror(m,f,r,'perMacpherson2003');
%
%   Input parameters:
%     m  : Item list from a localization experiment where each row
%          is response from a trial and the columns are as follows:
%
%          - 1: Azimuth angle of the target (in degrees).
%
%          - 2: Elevation angle of the target (in degrees).
%
%          - 3: Azimuth angle of the response (in degrees).
%
%          - 4: Elevation angle of the response (in degrees).
%
%          - 5: Lateral angle of the target (in degrees).
%
%          - 6: Polar angle of the target (in degrees).
%
%          - 7: Lateral angle of the response (in degrees).
%
%          - 8: Polar angle of the response (in degrees).
%
%          - 9 to 11: Cartesian X, Y, and Z coordinates of the target. Required only for errorflags being
%            'rFBC' or 'rF2B'.
%
%          - 12 to 14: Cartesian X, Y, and Z coordinates of the response. Required only for errorflags being
%            'rFBC' or 'rF2B'.
%
%     errorflag : Error metric to be calculated.
%
%     f  : Regression statistics for the frontal targets obtained from [f,r] = LOCALIZATIONERROR(m, 'sirp');.
%          Required only for the errorflag being 'perMacpherson2003'.
%
%     r  : Regression statistics for the rear targets obtained from [f,r] = LOCALIZATIONERROR(m, 'sirp');.
%          Required only for the errorflag being 'perMacpherson2003'.
%
%   Output parameters:
%     accL  : Accuracy bias (in degrees) in the lateral dimension.
%     precL : Precision error (in degrees) in the lateral dimension.
%     accP  : Accuracy bias (in degrees) in the polar dimension.
%     precP : Precision error (in degrees) in the polar dimension.
%     querr : Quadrant error rate (in percentage).
%     res   : Error metric as requested by errorflag.
%     meta  : Additional metadata as requested by errorflag.
%     par   : Additional calculation as requested by errorflag.
%
%   LOCALIZATIONERROR(..) calculates various psychoacoustic performance
%   parameters from responses of a sound-localization experiment.
%
%   [accL, precL, accP, precP, querr] = LOCALIZATIONERROR(m) returns the metrics 'accL', 'precL',
%   'precP', and 'querr'.
%
%   [res, meta, par] = LOCALIZATIONERROR(m, errorflag) returns in res the error
%   metric requested by errorflag, with additional metadata and calculation results
%   provided in meta and par, respectively.
%
%   The errorflag can be one of the following:
%
%     'absaccE'            Absolute elevation accuracy bias (in degrees), i.e., the absolute value
%                          of the circular average of elevation errors. See magnitude of elevation
%                          bias in Middlebrooks (1999).
%
%     'absaccL'            Absolute lateral accuracy bias (in degrees), i.e., the absolute value
%                          of the average of the (signed) errors in the lateral dimension. See magnitude
%                          of lateral bias in Middlebrooks (1999).
%
%     'accabsL'            Averaged absolute lateral erorr (in degrees), i.e., the
%                          average of the absolute (unsigned) lateral errors. Reference unclear. Note that
%                          the naming as accuracy is confusing.
%
%     'accabsP'            Averaged absolute polar error (in degrees), i.e., the circular
%                          average of the absolute (unsigned) polar errors. Reference unclear. Note that the
%                          naming as accuracy is confusing.
%
%     'accE'               Elevation accuracy bias (in degrees), i.e., the circular average of
%                          elevation errors. Reference unclear.
%
%     'accL'               Lateral acuracy bias (in degrees), i.e., the average of lateral errors. See lateral
%                          bias in Majdak et al. (2010).
%
%     'accP'               Polar accuracy bias (in degrees), i.e., the circular average of polar errors.
%                          Reference unclear.
%
%     'accPnoquerr'        As 'accP' but with quadrant errors (see 'querr') removed. See local polar bias*
%                          in Majdak et al. (2010).
%
%     'corrcoefL'          Lateral correlation coeffficient, i.e., the correlation coefficient between the
%                          response and target angles in the lateral dimension. meta provides the p-value
%                          of the correlation significance. See lateral target-response correlation coefficient*
%                          in Majdak et al. (2011).
%
%     'corrcoefP'          Polar median-plane correlation coeffficient, i.e., the correlation coefficient between
%                          the response and target angles in the polar dimension, considering responses around the
%                          median plane only, i.e., within the lateral angles of +-30 ^circ. meta provides
%                          the p-value of the correlation significance. See polar target-response correlation coefficient*
%                          in Majdak et al. (2011).
%
%     'gainL'              Lateral gain. It uses 'gainLstats'. Reference unclear.
%
%     'gainLstats'         Statistic details from the calculation of the lateral gain. See regress for a detailed
%                          description of the structure. Reference unclear.
%
%     'gainP'              Polar gain (between -1 and 1) as an average of 'gainPfront' and 'gainPrear'. See
%                          polar gain in Macpherson and Middlebrooks (2000).
%
%     'gainPfront'         Frontal polar gain (between -1 and 1), i.e., the  of SIRP done for frontal targets. It uses
%                          'sirp'. See polar gain in Macpherson and Middlebrooks (2000).
%
%     'gainPrear'          Rear polar gain (between -1 and 1), i.e., the slope of SIRP done for rear targets. It uses
%                          'sirp'. See polar gain in Macpherson and Middlebrooks (2000).
%
%     'perMacpherson2003'  Polar error rate (in percentage) as the rate of deviations larger than 45^circ from the
%                          linear regression calculated by SIRP for polar angles. It requires the results from 'sirp'
%                          provided as a separate inputs (see Usage above).
%
%     'precE'              Elevation precision error (in degrees) i.e., circular standard deviation of elevation errors.
%                          Reference unclear.
%
%     'precL'              Lateral precision error (in degrees), i.e., circular standard deviation of lateral errors.
%                          See lateral precision error in Majdak et al. (2010).
%
%     'precLcentral'       As 'precL' but considering only responses +-30 ^circ
%                          in elevation around the horizontal meridian plane. Reference unclear.
%
%     'precLregress'       Lateral scatter (in degrees) around the lateral regression line,
%                          i.e., the RMS of the response deviation from the lateral regression
%                          line, considering only the quasi-veridical responses, i.e., deviations
%                          smaller then 45^circ. It uses 'gainLstats'. See lateral angle scatter*
%                          in Macpherson and Middlebrooks (2000).
%                          Note that the naming as precision is confusing.
%
%     'precP'              Polar precision error (in degrees), i.e., circular standard deviation of polar errors.
%                          Reference unclear.
%
%     'precPmedian'        As 'precP' but considering targets around the median plane, i.e., with lateral angles
%                          in the range of +-30 ^circ, only. Reference unclear.
%
%     'precPmedianlocal'   As 'precpPmedian' but  with quadrant errors (see 'querrMiddlebrooks') removed.
%                          Similar but not the same as rms local polar error in Middlebrooks (1999).
%
%     'precPnoquerr'       As 'precP' but with quadrant errors (see 'querr') removed. See local polar
%                          precision error in Majdak et al. (2010).
%
%     'precPregressFront'  Polar frontal scatter (in degrees) around the polar regression line,
%                          i.e., the RMS of the response deviation from the polar regression
%                          line calculated by SIRP considering only targets located in the front
%                          and only the quasi-veridical responses, i.e., deviations
%                          smaller then 45^circ and. It uses 'sirp'. See polar angle scatter*
%                          in Macpherson and Middlebrooks (2000).
%                          Note that the naming as precision is confusing.
%
%     'precPregressRear'   Polar rear scatter (in degrees). As 'precPregressFront' but calculated
%                          considering only targets located in the rear. It uses 'sirp'.
%                          See polar angle scatter in Macpherson and Middlebrooks (2000).
%                          Note that the naming as precision is confusing.
%
%     'precPregress'       Polar scatter (in degrees) as an average of 'precPregressFront' and
%                          'precPregressRear'. See polar angle scatter in Macpherson and Middlebrooks (2000).
%                          Note that the naming as precision is confusing.
%
%     'pVeridicalL'        Proportion (in percentage) of lateral quasi-verdical responses. It uses 'gainLstats'.
%                          Reference unclear.
%
%     'pVeridicalPfront'   Proportion (in percentage) of polar frontal quasi-verdical polar responses. See
%                          quasi-veridical responses in Macpherson and Middlebrooks (2000).
%
%     'pVeridicalPrear'    Proportion (in percentage) of polar rear quasi-verdical polar responses. See
%                          quasi-veridical responses in Macpherson and Middlebrooks (2000).
%
%     'pVeridicalP'        Proportion (in percentage) of polar quasi-verdical polar responses.See quasi-veridical
%                          responses in Macpherson and Middlebrooks (2000).
%
%     'querr'              Quadrant error rate (in percentage), i.e., the rate of responses with the weighted
%                          polar errors outside the quadrant defined by errors within +-45 ^circ. The
%                          weighting is done as a function the lateral angle of the target. meta and par*
%                          provide the information about the number of responses in the correct quadrants, the
%                          number of responses within the lateral range, and the chance rate to achieve
%                          the quadrant errors by chance. See quadrant errors in Majdak et al. (2010).
%
%     'querrMiddlebrooks'  Quadrant error rate (in percentage), i.e., the rate of responses with
%                          the unweighted polar errors outside the quadrant defined by absolute
%                          polar errors within +-90 ^circ. meta and par provide the information
%                          about the number of confusions and the number of responses within the lateral range.
%                          See quadrant errors in Middlebrooks (1999).
%
%     'rmsL'               Lateral RMS error (in degrees), i.e., the root of the average of squared
%                          lateral errors. See rms lateral error in Middlebrooks (1999).
%
%     'rmsPmedian'         Polar median-plane RMS error (in degrees), i.e., the root of the average of squared
%                          polar errors considering only targets around the median plane, i.e., with lateral
%                          angles in the range of +-30 ^circ, only.  Reference unclear.
%
%     'rmsPmedianlocal'    As 'rmsPmedian' but excluding responses with quadrant errors as in
%                          'querrMiddlebrooks', i.e., absolute polar errors larger than 90 ^circ.
%                          See rms local polar error in Middlebrooks (1999).
%
%     'SCC'                Spherical correlation coefficient. See SCC in Carlile et al. (1997).
%
%     'sirp'               Polar regression statistics by means of the selective iterative regression procedure
%                          (SIRP) to exclude outliers and reversals from the computation of the regression lines
%                          used to calculate gain-based metrics. The SIRP is run 100 times and the result
%                          including the most responses (in other words, excluding the least outliers) is selected.
%                          Only targets around the median plane are considered, i.e., within the lateral range of
%                          +-30 ^circ. Outlier distance criterion is 40^circ. The SIRP is run separately
%                          for targets located in the frontal and the rear hemisphere with the results stored in res*
%                          and meta respectively (see regress for a detailed description of the structure).
%                          See p. 1873 in Macpherson and Middlebrooks (2000).
%
%     'rFBC'               Rate of front-back confusion (in percentage) in terms of being in the incorrect hemifield
%                          separated by the frontal plane. Responses on the interaural axis are not considered.
%                          Requires additional columns in the input. See front-back confusions in Carlile et al.
%                          (1997). Requires additional columns in the input.
%
%     'rF2B'               As 'rFBC' but considering front-to-back confusions only. Requires additional columns
%                          in the input. See McLachlan et al. (2024).
%
%     'rUDC'               Rate of up-down confusion (in percentage) in terms of being in the incorrect hemifield
%                          separated by the horizontal meridian plane. Responses directly on that plane are not
%                          considered. Requires additional columns in the input. See up-down confusions in
%                          Carlile et al. (1997) and McLachlan et al. (2024).
%
%     'slopePfront'        Polar frontal slope angle (in degrees) calcalated from the slope of the regression
%                          line for the frontal targets. Uses 'gainPfront'. Reference unclear.
%
%     'slopePrear'         Polar rear slope angle (in degrees) calcalated from the slope of the regression line
%                          for the rear targets. Uses 'gainPrear'. Reference unclear.
%
%     'slopeP'             Polar slope angle (in degrees) calcalated from the slope of the regression line for
%                          all targets. Uses 'gainP'. Reference unclear.
%
%
%
%
%
%   References:
%     G. McLachlan, P. Majdak, J. Reijniers, M. Mihocic, and H. Peremans.
%     Insights into dynamic sound localisation: A direction-dependent
%     comparison between human listeners and a Bayesian model, Apr. 2024.
%     
%     E. A. Macpherson and J. C. Middlebrooks. Localization of brief sounds:
%     Effects of level and background noise. The Journal of the Acoustical
%     Society of America, 108(1834), 2000.
%     
%     P. Majdak, M. J. Goupell, and B. Laback. Two-dimensional localization
%     of virtual sound sources in cochlear-implant listeners. Ear Hear,
%     32:198--208, 2011.
%     
%     P. Majdak, M. J. Goupell, and B. Laback. 3-D localization of virtual
%     sound sources: Effects of visual environment, pointing method and
%     training. Atten Percept Psycho, 72:454--469, 2010.
%     
%     J. C. Middlebrooks. Virtual localization improved by scaling
%     nonindividualized external-ear transfer functions in frequency. The
%     Journal of the Acoustical Society of America, 106:1493--1510, 1999.
%     
%     E. A. Macpherson and J. C. Middlebrooks. Vertical-plane sound
%     localization probed with ripple-spectrum noise. The Journal of the
%     Acoustical Society of America, 114:430--445, 2003.
%     
%     S. Carlile, P. Leong, and S. Hyams. The nature and distribution of
%     errors in sound localization by human listeners. Hearing research,
%     114(1):179--196, 1997.
%     
%
%   See also: exp_baumgartner2014 exp_barumerli2023
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/localizationerror.php


%   #Author: Piotr Majdak (2021): original implementation
%   #Author: Robert Baumgartner (2021): various additions, especially those based on sirpMacpherson2000
%   #Author: Glen McLachlan (2023): addition of rFBC, rF2B, rUDC, and maePnorev
%   #Author: Piotr Majdak (2024): major rework of the documentation for AMT 1.6, sirpMacpherson2000 renamed to sirp. maePnorev removed.
%   #Author: Michael Mihocic (2024): 360-deg wrapping fixed to be compatible to Octave code


% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

%% Check input options

definput.import={'localizationerror'};

[flags,kv]=ltfatarghelper({'f','r'},definput,varargin);


if size(m,2)==1,   m=m'; end


if isempty(flags.errorflag)
    nargout=6;
    thr=45;

    accL=mean(m(:,7)-m(:,5));
    varargout{1}=accL;
    precL=sqrt(sum((m(:,7)-m(:,5)-accL).^2)/size(m,1));
    varargout{2}=precL;
    w=0.5*cos(deg2rad(m(:,7))*2)+0.5;
    varargout{3}=mynpi2pi(circmean(m(:,8)-m(:,6),w));
    [x,mag]=circmean(m(:,8)-m(:,6));
    precP=rad2deg(acos(mag)*2)/2;
    varargout{4}=precP;
    idx=find((abs(mynpi2pi(m(:,8)-m(:,6))).*w)<=thr);
    querr=100-size(idx,1)/size(m,1)*100;
    varargout{5}=querr;
else
    %   if iscell(errorflag), errorflag=errorflag{1}; end
    %   if ~ischar(errorflag)
    %     error('ERR must be a string');
    %   end
    %   if size(errorflag,1)~=1, errorflag=errorflag'; end
    nargout=3;
    metadata=[];
    par=[];
    switch flags.errorflag
        case 'accL'
            accL=mean(m(:,7)-m(:,5));
            varargout{1}=accL;
            meta.ylabel='Lateral bias (deg)';
        case 'absaccL'
            accL=mean(m(:,7)-m(:,5));
            varargout{1}=abs(accL);
            meta.ylabel='Lateral absolute bias (deg)';
        case 'accabsL' %i.e. mean absolute error
            accL=mean(abs(m(:,7)-m(:,5)));
            varargout{1}=accL;
            meta.ylabel='Lateral absolute error (deg)';
        case 'corrcoefL'
            [r,p] = corrcoef([m(:,5) m(:,7)]);
            varargout{1}=r(1,2);
            par.par1=p(1,2);
            meta.ylabel='Lateral correlation coefficient';
            meta.par1 = 'p for testing the hypothesis of no correlation';
        case 'corrcoefP'
            idx=find(abs(m(:,7))<=30);
            [r,p] = corrcoef([m(idx,6) m(idx,8)]);
            varargout{1}=r(1,2);
            par.par1=p(1,2);
            meta.ylabel='Polar correlation coefficient';
            meta.par1 = 'p for testing the hypothesis of no correlation';
        case 'precL'
            accL=mean(m(:,7)-m(:,5));
            precL=sqrt(sum((m(:,7)-m(:,5)-accL).^2)/size(m,1));
            varargout{1}=precL;
            meta.ylabel='Lateral precision error (deg)';
        case 'precLcentral'
            idx=find(abs(m(:,4))<=30); % responses close to horizontal meridian
            accL=mean(m(idx,7)-m(idx,5));
            precL=sqrt(sum((m(idx,7)-m(idx,5)-accL).^2)/length(idx));
            varargout{1}=precL;
            meta.ylabel='Central lateral precision error (deg)';
        case 'rmsL'
            idx=find(abs(m(:,7))<=60);
            m=m(idx,:);
            rmsL=sqrt(sum((mynpi2pi(m(:,7)-m(:,5))).^2)/size(m,1));
            varargout{1}=rmsL;
            meta.ylabel='Lateral RMS error (deg)';
        case 'accP'
            varargout{1}=mynpi2pi(circmean(m(:,8)-m(:,6)));
            meta.ylabel='Polar bias (deg)';
        case 'accabsP'
            varargout{1}=mynpi2pi(circmean(abs(m(:,8)-m(:,6))));
            meta.ylabel='Polar absolute bias (deg)';
        case 'accPnoquerr'
            w=0.5*cos(deg2rad(m(:,7))*2)+0.5;
            idx=find(w>0.5);
            m=m(idx,:); w=w(idx,:);
            idx=find((abs(mynpi2pi(m(:,8)-m(:,6))).*w)<=45);
            varargout{1}=mynpi2pi(circmean(m(idx,8)-m(idx,6)));
            par.par1=length(idx);
            meta.ylabel='Local polar bias (deg)';
            meta.par1='Number of considered responses';
        case 'precP'
            w=0.5*cos(deg2rad(m(:,7))*2)+0.5;
            precP=circstd(m(:,8)-m(:,6),w);
            varargout{1}=precP;
            meta.ylabel='Polar precision (deg)';
        case 'precPnoquerr'
            %         w=0.5*cos(deg2rad(m(:,7))*2)+0.5;
            %         idx=find(w>0.5);
            %         thr=45; % threshold for the choice: quadrant error or not
            %         m=m(idx,:); w=w(idx,:);
            range=360; % polar range of targets
            thr=45; % threshold for the choice: quadrant error or not
            latmax=0.5*180*(acos(4*thr/range-1))/pi;
            idx=find(abs(m(:,7))<latmax); % targets outside not considered
            m=m(idx,:);
            w=0.5*cos((m(:,7))*2*pi/180)+0.5;
            idx=find((abs(mynpi2pi(m(:,8)-m(:,6))).*w)<=thr);
            m=m(idx,:);
            w=0.5*cos((m(:,7))*pi/180*2)+0.5;
            precP=circstd(m(:,8)-m(:,6),w);
            varargout{1}=real(precP);
            meta.ylabel='Local polar precision error (deg)';
        case 'querr'
            range=360; % polar range of targets
            thr=45; % threshold for the choice: quadrant error or not
            latmax=0.5*180*(acos(4*thr/range-1))/pi;
            idx=find(abs(m(:,7))<latmax); % targets outside not considered
            m=m(idx,:);
            w=0.5*cos(pi*(m(:,7))/180*2)+0.5; % weigthing of the errors
            corrects=size(find((abs(mynpi2pi(m(:,8)-m(:,6))).*w)<=thr),1);
            totals=size(m,1);
            chancerate=2*thr/range./w;
            wrongrate=100-mean(chancerate)*100;
            querr=100-corrects/totals*100;
            varargout{1}=querr;
            meta.ylabel='Weighted quadrant errors (%)';
            par.par1=corrects;
            meta.par1='Number of correct responses';
            par.par2=totals;
            meta.par2='Number of responses within the lateral range';
            par.par3=wrongrate; % valid only for targets between 0 and 180°
            meta.par3='Wrong rate, valid only for targets between 0 and 180°';

        case 'querrMiddlebrooks' % as in Middlebrooks (1999); comparable to COC from Best et al. (2005)
            idx=abs(m(:,7))<=30;
            m=m(idx,:);
            idx=find((abs(mynpi2pi(m(:,8)-m(:,6))))>90);
            querr=size(idx,1)/size(m,1)*100;
            % chance performance (FIXME: not working with exp_baumgartner2014!)
            %       tang = m(:,6);
            %       rang = min(tang):max(tang); % assume listener knows target range
            %       p = ones(length(rang),length(tang)); % equally distributed response probabilities
            %       chance = baumgartner2014_pmv2ppp(p,tang,rang,'QE');
            varargout{1}=querr;
            meta.ylabel='Quadrant errors (%)';
            par.par1=size(idx,1);
            meta.par1='Number of confusions';
            par.par2=size(m,1);
            meta.par2='Number of responses within the lateral range';
            %       par.chance=chance;
            %       meta.chance='Chance performance';

        case 'querrMiddlebrooksRAU' % as in Middlebrooks (1999) but calculated in rau
            idx=find(abs(m(:,7))<=30);
            m=m(idx,:);
            idx=find((abs(mynpi2pi(m(:,8)-m(:,6))))<=90);
            querr=100-size(idx,1)/size(m,1)*100;
            varargout{1}=rau(querr,size(m,1));
            meta.ylabel='RAU quadrant errors';
            par.par1=size(idx,1);
            meta.par1='Number of confusions';
            par.par2=size(m,1);
            meta.par2='Number of responses within the lateral range';
        case 'rFBC'
            idx1 = find(sign(m(:,9))~=sign(m(:,12)) & abs(m(:,9))>0.01);
            idx2 = abs(m(:,9))>0.01;
            varargout{1}=size(idx1,1)/size(idx2,1)*100;
            meta.ylabel='FBC rate (%)';
        case 'rF2B' %front-to-back
            idx1 = find(sign(m(:,9))~=sign(m(:,12)) & abs(m(:,9))>0.01);
            idx2 = find(sign(m(:,9))~=sign(m(:,12)) & (m(:,9))>0.01);
            varargout{1}=size(idx2,1)/size(idx1,1)*100;
            meta.ylabel='F2B rate (%)';
        case 'rUDC'
            idx1 = find(sign(m(:,11))~=sign(m(:,14)) & abs(m(:,11))>0.01);
            idx2=abs(m(:,11))>0.01;
            varargout{1}=size(idx1,1)/size(idx2,1)*100;
            meta.ylabel='UDC rate (%)';
        case 'accE'
            varargout{1}=mynpi2pi(circmean(m(:,4)-m(:,2)));
            meta.ylabel='Elevation bias (deg)';
        case 'absaccE'
            varargout{1}=abs(mynpi2pi(circmean(m(:,4)-m(:,2))));
            meta.ylabel='Absolute elevation bias (deg)';
        case 'precE'
            precE=circstd(m(:,4)-m(:,2));
            varargout{1}=precE;
            meta.ylabel='Elevation precision error (deg)';
        case 'lateral'        % obsolete
            nargout=2;
            varargout{1}=accL;
            varargout{2}=precL;
        case 'polar'          % obsolete
            nargout=3;
            varargout{1}=accP;
            varargout{2}=precP;
            varargout{3}=querr;
        case 'precPmedianlocal'
            idx=find(abs(m(:,7))<=30);
            m=m(idx,:);
            idx=find(abs(mynpi2pi(m(:,8)-m(:,6)))<90);
            if isempty(idx), error('Quadrant errors of 100%, local bias is NaN'); end
            precPM=circstd(m(idx,8)-m(idx,6));
            varargout{1}=precPM;
            meta.ylabel='Local central precision error (deg)';
        case 'precPmedian'
            idx=find(abs(m(:,7))<=30);
            m=m(idx,:);
            precPM=circstd(m(:,8)-m(:,6));
            varargout{1}=precPM;
            meta.ylabel='Central precision error (deg)';
        case 'rmsPmedianlocal'
            idx=find(abs(m(:,7))<=30);
            m=m(idx,:);
            idx=find(abs(mynpi2pi(m(:,8)-m(:,6)))<90);
            rmsPlocal=sqrt(sum((mynpi2pi(m(idx,8)-m(idx,6))).^2)/size(idx,1));
            varargout{1}=rmsPlocal;
            meta.ylabel='Local central RMS error (deg)';
            % chance performance (FIXME: not working with exp_baumgartner2014!)
            %       tang = m(:,6);
            %       rang = min(tang):max(tang); % assume listener knows target range
            %       p = ones(length(rang),length(tang)); % equally distributed response probabilities
            %       chance = baumgartner2014_pmv2ppp(p,tang,rang,'PE');
            %       par.chance = chance;
            %       meta.chance = 'Chance performance';
        case 'rmsPmedian'
            idx=find(abs(m(:,7))<=30);
            m=m(idx,:);
            rmsP=sqrt(sum((mynpi2pi(m(:,8)-m(:,6))).^2)/size(m,1));
            varargout{1}=rmsP;
            meta.ylabel='Central RMS error (deg)';
        case 'SCC'
            trgt = m(:,[1 2]);
            resp = m(:,[3 4]);
            T = pol2dcos(trgt);
            R = pol2dcos(resp);
            sxy = T' * R;
            sxx = T' * T;
            syy = R' * R;
            scc = det(sxy) / sqrt(det(sxx) * det(syy));
            varargout{1}=scc;
            meta.ylabel='Spatial correlation coefficient';

        case 'gainLstats'

            [l.b,l.bint,l.r,l.rint,l.stats]=regress(m(:,7),[ones(length(m),1) m(:,5)]);
            varargout{1}=l;
            meta.ylabel='Lateral gain';

        case 'gainL'

            l = localizationerror(m,'gainLstats');
            varargout{1}=l.b(2);
            meta.ylabel='Lateral gain';

        case 'precLregress'

            l = localizationerror(m,'gainLstats');
            x = -90:90;
            y = l.b(2)*m(:,5) + l.b(1); % linear regression
            dev = m(:,7) - y; % deviation
            dev = dev(abs(dev)<=45); % include only quasi-veridical responses
            prec = rms(dev);
            varargout{1} = prec;
            meta.ylabel = 'Lateral scatter (deg)';

        case 'pVeridicalL'
            tol = 45; % tolerance of lateral angle error for quasi-veridical responses
            l = localizationerror(m,'gainLstats');
            x = -90:90;
            y = l.b(2)*m(:,5) + l.b(1); % linear regression
            dev = m(:,7) - y; % deviation wrapped to +-180 deg
            prop = sum(abs(dev)<=tol)/length(dev);
            varargout{1} = prop*100;
            meta.ylabel = '% lateral quasi-veridical';

        case {'sirpMacpherson2000', 'sirp'}
            delta = 40; % outlier tolerance in degrees
            Nmin = 5; % minimum number of responses used for regression
            maxiter = 100; % max number of iterations

            % Only responses for targets located within 30 degrees of the median plane are included
            m = m( abs(m(:,5))<=30,: );

            for frontback = 1:2 % Analyze front and back hemispheres separately

                if frontback == 1 % Front
                    mhemi = m( m(:,6)<=90 ,:); % frontal target locations
                    idinit = mhemi(:,8)<=90; % initialization with correct responses
                else % Back
                    mhemi = m( m(:,6)>=90 ,:); % rear targets
                    idinit = mhemi(:,8)>=90;  % initialization with correct responses
                end

                if length(idinit)<Nmin
                    r.b = nan(1,2);
                    r.stats = nan(1,4);
                else
                    iditer = false(length(idinit),maxiter);
                    y = mhemi(:,8); % response
                    x = mhemi(:,6); % target
                    for iter = 1:maxiter
                        B=regress(y(idinit),[ones(sum(idinit),1) mhemi(idinit,6)]);
                        yhat=B(2)*x+B(1);
                        dev = mod( (y-yhat) +180,360) -180; % deviation wrapped to +-180 deg
                        iditer(:,iter)= abs(dev) < delta;
                        if isequal(iditer(:,iter),idinit)
                            break % because it converged
                        else
                            idinit = iditer(:,iter);
                        end
                    end
                    [nselect,iopt] = max(sum(iditer));
                    idselect = iditer(:,iopt);

                    [r.b,r.bint,r.r,r.rint,r.stats]=regress(...
                        mhemi(idselect,8),[ones(nselect,1) mhemi(idselect,6)]);

                end
                varargout{frontback}=r;
            end

            par='SIRP results';

        case 'gainPfront'

            f = localizationerror(m,'sirpMacpherson2000');
            varargout{1}=f.b(2);
            meta.ylabel='Frontal polar gain';

        case 'gainPrear'

            [tmp,r] = localizationerror(m,'sirpMacpherson2000');
            varargout{1}=r.b(2);
            meta.ylabel='Rear polar gain';

        case 'gainP'

            [f,r] = localizationerror(m,'sirpMacpherson2000');
            varargout{1}=(f.b(2)+r.b(2))/2;
            meta.ylabel='Polar gain';

        case 'slopePfront'

            g = localizationerror(m,'gainPfront');
            varargout{1} = rad2deg(acos(1./sqrt(g.^2+1)));
            meta.ylabel='Frontal polar regression slope';

        case 'slopePrear'

            g = localizationerror(m,'gainPrear');
            varargout{1} = rad2deg(acos(1./sqrt(g.^2+1)));
            meta.ylabel='Rear polar regression slope';

        case 'slopeP'

            g = localizationerror(m,'gainP');
            varargout{1} = rad2deg(acos(1./sqrt(g.^2+1)));
            meta.ylabel='Polar regression slope';

        case 'pVeridicalPfront'

            tol = 45; % tolerance of polar angle error for quasi-veridical responses

            f = localizationerror(m,'sirpMacpherson2000');

            mf = m( abs(m(:,5))<=30 & m(:,6)< 90 ,:); % frontal central data only

            x = -90:270;
            yf=f.b(2)*mf(:,6)+f.b(1); % linear prediction for flat, frontal targets

            devf = mod( (mf(:,8)-yf) +180,360) -180; % deviation wrapped to +-180 deg

            pVer = sum(abs(devf) <= tol) / length(devf);

            varargout{1}=pVer*100;
            meta.ylabel = '% quasi-veridical (frontal)';

        case 'pVeridicalPrear'

            tol = 45; % tolerance of polar angle error for quasi-veridical responses

            [~,r] = localizationerror(m,'sirpMacpherson2000');

            mr = m( abs(m(:,5))<=30 & m(:,6)>=90 ,:); % rear central data only

            x = -90:270;
            yr = r.b(2)*mr(:,6) + r.b(1); % linear prediction for flat, rear targets

            devr = mod( (mr(:,8)-yr) +180,360) -180; % deviation wrapped to +-180 deg

            pVer = sum(abs(devr) <= tol) / length(devr);

            varargout{1}=pVer*100;
            meta.ylabel = '% quasi-veridical (rear)';

        case 'pVeridicalP'

            tol = 45; % tolerance of polar angle error for quasi-veridical responses
            [f,r] = localizationerror(m,'sirpMacpherson2000');

            mf = m( abs(m(:,5))<=30 & m(:,6)< 90 ,:); % frontal central targets
            mr = m( abs(m(:,5))<=30 & m(:,6)>=90 ,:); % rear central targets

            x = -90:270;
            yf = f.b(2)*mf(:,6) + f.b(1); % linear prediction for flat, frontal targets
            yr = r.b(2)*mr(:,6) + r.b(1); % linear prediction for flat, rear targets

            devf = mod( (mf(:,8)-yf) +180,360) -180; % deviation wrapped to +-180 deg
            devr = mod( (mr(:,8)-yr) +180,360) -180; % deviation wrapped to +-180 deg

            pVerf = sum(abs(devf) <= tol) / length(devf);
            pVerr = sum(abs(devr) <= tol) / length(devr);

            pVer = (pVerf + pVerr)/2;

            varargout{1}=pVer*100;
            meta.ylabel = '% quasi-veridical';

        case 'precPregressFront'

            tol = 45; % tolerance of polar angle error for quasi-veridical responses

            f = localizationerror(m,'sirpMacpherson2000');

            mf = m( abs(m(:,5))<=30 & m(:,6)< 90 ,:); % frontal central targets only

            x = -90:270;
            yf = f.b(2)*mf(:,6) + f.b(1); % linear prediction for flat, frontal targets

            devf = mod( (mf(:,8)-yf) +180,360) -180; % deviation wrapped to +-180 deg

            dev = devf(abs(devf)<=tol); % include only quasi-veridical responses
            prec = rms(dev);
            varargout{1} = prec;
            meta.ylabel = 'Frontal polar scatter (deg)';

        case 'precPregressRear'

            tol = 45; % tolerance of polar angle error for quasi-veridical responses

            [~,r] = localizationerror(m,'sirpMacpherson2000');

            mr = m( abs(m(:,5))<=30 & m(:,6)>=90 ,:); % rear central targets only

            x = -90:270;
            yr = r.b(2)*mr(:,6) + r.b(1); % linear prediction for flat, rear targets

            devr = mod( (mr(:,8)-yr) +180,360) -180; % deviation wrapped to +-180 deg

            dev = devr(abs(devr)<=tol); % include only quasi-veridical responses
            prec = rms(dev);
            varargout{1} = prec;
            meta.ylabel = 'Rear polar scatter (deg)';

        case 'precPregress'

            precF = localizationerror(m,'precPregressFront');
            precR = localizationerror(m,'precPregressRear');
            prec = (precF+precR)/2;
            varargout{1} = prec;
            meta.ylabel = 'Polar scatter (deg)';

        case 'perMacpherson2003'

            if isempty(kv.f) || isempty(kv.r)
                amt_disp('Regression coefficients missing! Input is interpreted as baseline data!','documentation');
                amt_disp('For this analysis the results from `sirpMacpherson2000()` for baseline data','documentation');
                amt_disp('are required and must be handled as `localizationerror(m,f,r,...)`.','documentation');
                [kv.f,kv.r] = localizationerror(m,'sirpMacpherson2000');
            end

            plotflag = false;
            tol = 45; % tolerance of polar angle to be not counted as polar error

            mf = m( abs(m(:,5))<=30 & m(:,6)< 90 ,:); % frontal central targets only
            mr = m( abs(m(:,5))<=30 & m(:,6)>=90 ,:); % rear central targets only

            x = -90:270;
            yf=kv.f.b(2)*mf(:,6)+kv.f.b(1); % linear prediction for flat, frontal targets
            yr=kv.r.b(2)*mr(:,6)+kv.r.b(1); % linear prediction for flat, rear targets

            devf = mod( (mf(:,8)-yf) +180,360) -180; % deviation wrapped to +-180 deg
            devr = mod( (mr(:,8)-yr) +180,360) -180;

            f.pe = sum(abs(devf) > tol);
            r.pe = sum(abs(devr) > tol);

            per = (f.pe + r.pe) / size(m,1) * 100; % polar error rate
            varargout{1} = per;
            meta.ylabel = 'Polar error rate (%)';

            if plotflag
                plot(m(:,6),m(:,8),'ko');
                axis equal
                axis tight
                hold on
                plot(mf(:,6),yf,'LineWidth',2);
                plot(mr(:,6),yr,'LineWidth',2);
                plot(mf(:,6),yf+45,'r','LineWidth',2);
                plot(mf(:,6),yf-45,'r','LineWidth',2);
                plot(mr(:,6),yr+45,'r','LineWidth',2);
                plot(mr(:,6),yr-45,'r','LineWidth',2);
                title(['PER: ' num2str(per,2) '%'])
            end

        otherwise
            error(['Unknown ERR: ' err]);
    end
    if length(varargout) < 2
        varargout{2}=meta;
    end
    if length(varargout) < 3
        varargout{3}=par;
    end
end

end

function out_deg=mynpi2pi(ang_deg)
ang=ang_deg/180*pi;
out_rad=sign(ang).*((abs(ang)/pi)-2*ceil(((abs(ang)/pi)-1)/2))*pi;
out_deg=out_rad*180/pi;
end

function [phi,mag]=circmean(azi,dim)
% [PHI,MAG]=circmean(AZI,DIM)
%
% Calculate the average angle of AZI according
% to the circular statistics (Batschelet, 1981).
%
% For vectors, CIRCMEAN(AZI) is the mean value of the elements in AZI. For
% matrices, CIRCMEAN(AZI) is a row vector containing the mean value of
% each column.  For N-D arrays, CIRCMEAN(azi) is the mean value of the
% elements along the first non-singleton dimension of AZI.
%
% circmean(AZI,DIM) takes the mean along the dimension DIM of AZI.
%
% PHI is the average angle in deg, 0..360�
% MAG is the magnitude showing the significance of PHI (kind of dispersion)
%   MAG of zero shows that there is no average of AZI.
%   MAG of one shows a highest possible significance
%   MAG can be represented in terms of standard deviation in deg by using
%       rad2deg(acos(MAG)*2)/2
%
% [PHI,MAG]=circmean(AZI,W) calculates a weighted average where each sample
% in AZI is weighted by the corresponding entry in W.
%
% Piotr Majdak, 6.3.2007

if isempty(azi) % no values
    phi=NaN;
    mag=NaN;
    return;
end

if prod(size(azi))==1 % one value only
    phi=azi;
    mag=1;
    return;
end

if ~exist('dim')  % find the dimension
    dim = min(find(size(azi)~=1));
    w=ones(size(azi));
elseif prod(size(dim))~=1
    % dim vector represents weights
    w=dim;
    dim = min(find(size(azi)~=1));
end


x=deg2rad(azi);

s=mean(sin(x).*w,dim)/mean(w);
c=mean(cos(x).*w,dim)/mean(w);

y=zeros(size(s));
for ii=1:length(s)
    if s(ii)>0 & c(ii)>0
        y(ii)=atan(s(ii)/c(ii));
    elseif c(ii)<0
        y(ii)=atan(s(ii)/c(ii))+pi;
    elseif s(ii)<0 & c(ii)>0
        y(ii)=atan(s(ii)/c(ii))+2*pi;
    elseif s(ii)==0
        y(ii)=0;
    else
        y(ii)=NaN;
    end
end
mag=sqrt(s.*s+c.*c);

phi = mod(rad2deg(y), 360);
phi((phi==0) & (rad2deg(y)>0)) = 360;

end

function mag=circstd(azi,dim)

% MAG=circstd(AZI,DIM)
%
% Calculate the standard deviation angle (in deg) of AZI (in deg) according
% to the circular statistics (Batschelet, 1981).
%
% For vectors, CIRCSTD(AZI) is the std of the elements in AZI. For
% matrices, CIRCSTD(AZI) is a row vector containing the std of
% each column.  For N-D arrays, CIRCSTD(azi) is the std value of the
% elements along the first non-singleton dimension of AZI.
%
% CIRCSTD(AZI,DIM) takes the std along the dimension DIM of AZI.
%
%
% MAG=CIRCSTD(AZI,W) calculates a weighted std where each vector strength
% of AZI is weighted by the corresponding entry in W.
%
% Piotr Majdak, 21.08.2008

if isempty(azi) % no values
    mag=NaN;
    return;
end

if prod(size(azi))==1 % one value only
    mag=0;
    return;
end

if ~exist('dim')  % find the dimension
    [phi,mag]=circmean(azi);
elseif prod(size(dim))~=1
    [phi,mag]=circmean(azi,dim);
end

mag=rad2deg(sqrt(2*(1-mag)));

end


