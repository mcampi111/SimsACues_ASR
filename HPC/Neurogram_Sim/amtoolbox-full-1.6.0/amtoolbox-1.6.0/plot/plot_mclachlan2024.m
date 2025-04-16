function plot_mclachlan2024(fig,met,dirs)
% plot the output from mclachlan2024_metrics
% dirs: true source directions
% met:  output struct from mclachlan2024_metrics
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/plot/plot_mclachlan2024.php



lw=1; %linewidth
c1=[0 0.4470 0.7410]; %colour 1
c2=[0.8500 0.3250 0.0980]; %colour 2

if strcmp(fig,'fig1')
%% Kent plot
hold on;
colormap([1 1 1]);
set(gca,'Visible','off');

% draw a sphere
daz=30;
AZgrid=repmat((-90:90),length(-180:daz:180),1)'*pi/180; 
ELgrid=repmat((-180:daz:180)',1,length(-90:90))'*pi/180; 
[xgrid1,zgrid1,ygrid1]=sph2cart(AZgrid,ELgrid,1);
[xgrid2,zgrid2,ygrid2]=sph2cart(ELgrid,AZgrid,1);
plot3(xgrid1,ygrid1,zgrid1,'Color',[.7 .7 .7]);
hold on
plot3(xgrid2,ygrid2,zgrid2,'Color',[.7 .7 .7]);
view(90,0);

scatter3(dirs(:,1),dirs(:,2),dirs(:,3),30,'xk'); 		% plot target locations
%plot bias
q1=quiver3(dirs(:,1),dirs(:,2),dirs(:,3),met.bias_perdir(:,1)-dirs(:,1),met.bias_perdir(:,2)-dirs(:,2),met.bias_perdir(:,3)-dirs(:,3),'off','Color','k');
q1.MaxHeadSize = 0.05;
q1.LineWidth = 1.5;
% plot kent distributions
for i=1:size(dirs,1) 
    p=fill3(met.kentdist(i,:,1),met.kentdist(i,:,2),met.kentdist(i,:,3),'k');
    p.FaceAlpha = 0.1;
end

axis equal
daspect([1 1 1]);
pbaspect([1 1 1]);

elseif strcmp(fig,'fig2')
%% FBC plot
daz=30;
AZgrid=repmat((-90:90),length(-180:daz:180),1)'*pi/180; 
ELgrid=repmat((-180:daz:180)',1,length(-90:90))'*pi/180; 
[xgrid1,zgrid1,ygrid1]=sph2cart(AZgrid,ELgrid,1);
[xgrid2,zgrid2,ygrid2]=sph2cart(ELgrid,AZgrid,1);
plot3(xgrid1,ygrid1,zgrid1,'Color',[.7 .7 .7]);
hold on
plot3(xgrid2,ygrid2,zgrid2,'Color',[.7 .7 .7]);
view(90,0);

scatter3(dirs(:,1),dirs(:,2),dirs(:,3),600,met.fbc_perdir(:),'filled');
cmap=colormap("bone");
colormap(flipud(cmap))
caxis([0 40])
colorbar("southoutside")
scatter3(dirs(:,1),dirs(:,2),dirs(:,3),50,'k','Marker','x','LineWidth',1);
title('front-back confusions');
axis off

xPlane = [0 0 0 0]; yPlane =[-1,1,1,-1] ; zPlane = [-1,-1,1,1];
patch(xPlane, yPlane, zPlane, 'w');

axis equal
daspect([1 1 1]);
pbaspect([1 1 1]);

elseif strcmp(fig,'fig3')
    dur=[10,50,100,200,500,1000];

    figure;
    
    subplot(3,1,1)
    ylabel('lateral RMSE [deg]')
    errorbar(dur-1,mean(met.mod.s.rmsL,2),std(met.mod.s.rmsL,[],2),'Color',c1,'LineWidth',lw); hold on;
    L(1)=plot(dur-1,mean(met.mod.s.rmsL,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw);
    errorbar(dur+1,mean(met.mod.d.rmsL,2),std(met.mod.d.rmsL,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(2)=plot(dur+1,mean(met.mod.d.rmsL,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    errorbar(499,mean(met.emp.s.rmsL),std(met.emp.s.rmsL),'Color',c1,'LineWidth',lw)
    L(3)=plot(499,mean(met.emp.s.rmsL),'s--','MarkerSize',5,'Color',c1,'LineWidth',lw,'MarkerFaceColor',c1); 
    yline(mean(met.emp.s.rmsL),'--','Color',c1,'LineWidth',lw);
    yline(mean(met.emp.d.rmsL),'--','Color',c2,'LineWidth',lw);
    errorbar(501,mean(met.emp.d.rmsL),std(met.emp.d.rmsL),'Color',c2,'LineWidth',lw)
    L(4)=plot(501,mean(met.emp.d.rmsL),'s--','MarkerSize',5,'Color',c2,'LineWidth',lw,'MarkerFaceColor',c2); 
    rectangle('Position',[0 mean(met.emp.s.rmsL)-std(met.emp.s.rmsL) 1010 2*std(met.emp.s.rmsL)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[0 mean(met.emp.d.rmsL)-std(met.emp.d.rmsL) 1010 2*std(met.emp.d.rmsL)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    
    legend('M-Stat','M-Dyn','B-Stat','B-Dyn')
    xlim([0 1010])
    ylim([-1,10])
    
    subplot(3,1,2)
    errorbar(dur-1,mean(met.mod.s.rmsP,2),std(met.mod.s.rmsP,[],2),'Color',c1,'LineWidth',lw); hold on;
    L(1)=plot(dur-1,mean(met.mod.s.rmsP,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw);
    errorbar(dur+1,mean(met.mod.d.rmsP,2),std(met.mod.d.rmsP,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(2)=plot(dur+1,mean(met.mod.d.rmsP,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    errorbar(499,mean(met.emp.s.rmsP),std(met.emp.s.rmsP),'Color',c1,'LineWidth',lw)
    L(3)=plot(499,mean(met.emp.s.rmsP),'s--','MarkerSize',5,'Color',c1,'LineWidth',lw,'MarkerFaceColor',c1); 
    yline(mean(met.emp.s.rmsP),'--','Color',c1,'LineWidth',lw);
    yline(mean(met.emp.d.rmsP),'--','Color',c2,'LineWidth',lw);
    errorbar(501,mean(met.emp.d.rmsP),std(met.emp.d.rmsP),'Color',c2,'LineWidth',lw)
    L(4)=plot(501,mean(met.emp.d.rmsP),'s--','MarkerSize',5,'Color',c2,'LineWidth',lw,'MarkerFaceColor',c2); 
    rectangle('Position',[0 mean(met.emp.s.rmsP)-std(met.emp.s.rmsP) 1010 2*std(met.emp.s.rmsP)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[0 mean(met.emp.d.rmsP)-std(met.emp.d.rmsP) 1010 2*std(met.emp.d.rmsP)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylabel('polar RMSE [deg]')
    xlim([0 1010])
    ylim([-5,50])

    subplot(3,1,3)
    errorbar(dur-1,mean(met.mod.s.querr,2),std(met.mod.s.querr,[],2),'Color',c1,'LineWidth',lw); hold on;
    L(1)=plot(dur-1,mean(met.mod.s.querr,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw);
    errorbar(dur+1,mean(met.mod.d.querr,2),std(met.mod.d.querr,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(2)=plot(dur+1,mean(met.mod.d.querr,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    errorbar(499,mean(met.emp.s.querr),std(met.emp.s.querr),'Color',c1,'LineWidth',lw)
    L(3)=plot(499,mean(met.emp.s.querr),'s--','MarkerSize',5,'Color',c1,'LineWidth',lw,'MarkerFaceColor',c1); 
    yline(mean(met.emp.s.querr),'--','Color',c1,'LineWidth',lw);
    yline(mean(met.emp.d.querr),'--','Color',c2,'LineWidth',lw);
    errorbar(501,mean(met.emp.d.querr),std(met.emp.d.querr),'Color',c2,'LineWidth',lw)
    L(4)=plot(501,mean(met.emp.d.querr),'s--','MarkerSize',5,'Color',c2,'LineWidth',lw,'MarkerFaceColor',c2); 
    rectangle('Position',[0 mean(met.emp.s.querr)-std(met.emp.s.querr) 1010 2*std(met.emp.s.querr)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[0 mean(met.emp.d.querr)-std(met.emp.d.querr) 1010 2*std(met.emp.d.querr)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylabel('QE rate [%]')
    xlim([0 1010])
    ylim([-5,50])   
    xlabel('duration [ms]')

elseif strcmp(fig,'fig4')
    itd=[0.3,0.6,1.2,1.8,2.4,3.0];
    figure;
    subplot(3,1,1)
    errorbar(itd-0.005,mean(met.mod.s.rmsL,2),std(met.mod.s.rmsL,[],2),'Color',c1,'LineWidth',lw); hold on;
    L(1)=plot(itd-0.005,mean(met.mod.s.rmsL,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on%,
    errorbar(itd,mean(met.mod.d.rmsL,2),std(met.mod.d.rmsL,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(2)=plot(itd,mean(met.mod.d.rmsL,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    yline(mean(met.emp.s.rmsL),'--','Color',c1,'LineWidth',lw);
    yline(mean(met.emp.d.rmsL),'--','Color',c2,'LineWidth',lw);
    rectangle('Position',[0.25 mean(met.emp.s.rmsL)-std(met.emp.s.rmsL) 2.8 2*std(met.emp.s.rmsL)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[0.25 mean(met.emp.d.rmsL)-std(met.emp.d.rmsL) 2.8 2*std(met.emp.d.rmsL)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    legend('M.S.','M.D.','B.S.','B.D.','Location','NorthWest')
    ylabel('lateral RMSE [deg]')
    ylim([0,15]);
    xlim([0.25,3.05])
    
    subplot(3,1,2)
    errorbar(itd-0.005,mean(met.mod.s.rmsP,2),std(met.mod.s.rmsP,[],2),'Color',c1,'LineWidth',lw); hold on;
    L(1)=plot(itd-0.005,mean(met.mod.s.rmsP,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on%,
    errorbar(itd,mean(met.mod.d.rmsP,2),std(met.mod.d.rmsP,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(2)=plot(itd,mean(met.mod.d.rmsP,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    yline(mean(met.emp.s.rmsP),'--','Color',c1,'LineWidth',lw);
    yline(mean(met.emp.d.rmsP),'--','Color',c2,'LineWidth',lw);
    rectangle('Position',[0.25 mean(met.emp.s.rmsP)-std(met.emp.s.rmsP) 2.8 2*std(met.emp.s.rmsP)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[0.25 mean(met.emp.d.rmsP)-std(met.emp.d.rmsP) 2.8 2*std(met.emp.d.rmsP)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylabel('polar RMSE [deg]')
    ylim([5,35]);
    xlim([0.25,3.05])
    
    subplot(3,1,3)
    errorbar(itd-0.005,mean(met.mod.s.querr,2),std(met.mod.s.querr,[],2),'Color',c1,'LineWidth',lw); hold on;
    L(1)=plot(itd-0.005,mean(met.mod.s.querr,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on%,
    errorbar(itd,mean(met.mod.d.querr,2),std(met.mod.d.querr,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(2)=plot(itd,mean(met.mod.d.querr,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    yline(mean(met.emp.s.querr),'--','Color',c1,'LineWidth',lw);
    yline(mean(met.emp.d.querr),'--','Color',c2,'LineWidth',lw);
    rectangle('Position',[0.25 mean(met.emp.s.querr)-std(met.emp.s.querr) 2.8 2*std(met.emp.s.querr)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[0.25 mean(met.emp.d.querr)-std(met.emp.d.querr) 2.8 2*std(met.emp.d.querr)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylabel('QE rate [%]')
    ylim([0,15]);
    xlim([0.25,3.05])
    
    xlabel('\sigma_{itd}')


elseif strcmp(fig,'fig5')
    figure;
    Cmap1 = lines(5);
    sig=[0,5,10,15];

    % plot Kalman filters
    sig_H=5; sig_u=eps;
    [Theta_H,y_H,mu_H]=kalmanfilter(sig_H,sig_u);
    subplot(4,2,1)
    hold on
    x=linspace(0,100,20);
    plot(x,mu_H(:,1),'LineWidth',1.5,'Color',Cmap1(4,:));hold on
    plot(x,Theta_H(:,1),'LineWidth',1.5,'Color',Cmap1(5,:)); 
    plot(x,y_H(:,1),'LineWidth',1.5,'Color',Cmap1(3,:));
    ylim([-15,20])
    ylabel('head azimuth (deg)')
    xlabel('duration (ms)')
    legend('$$\hat{\theta}_H$$','$$\theta_H$$','$$y_H$$','Interpreter','Latex','Location','northwest')

    sig_H=5; sig_u=2;
    [Theta_H,y_H,mu_H]=kalmanfilter(sig_H,sig_u);
    subplot(4,2,2)
    hold on
    x=linspace(0,100,20);
    plot(x,mu_H(:,1),'LineWidth',1.5,'Color',Cmap1(4,:));hold on
    plot(x,Theta_H(:,1),'LineWidth',1.5,'Color',Cmap1(5,:)); 
    plot(x,y_H(:,1),'LineWidth',1.5,'Color',Cmap1(3,:));
    ylim([-15,20])
    ylabel('head azimuth (deg)')
    xlabel('duration (ms)')

    % LEFT PLOT (sig_u=0)
    rmsL_s=met.mod.s.rmsL(1:2:end,:); %uneven indices
    rmsL_d=met.mod.d.rmsL(1:2:end,:);
    rmsP_s=met.mod.s.rmsP(1:2:end,:);
    rmsP_d=met.mod.d.rmsP(1:2:end,:);
    querr_s=met.mod.s.querr(1:2:end,:);
    querr_d=met.mod.d.querr(1:2:end,:);
    
    subplot(4,2,3)
    errorbar(sig-0.02,mean(rmsL_s,2),std(rmsL_s,[],2),'Color',c1,'LineWidth',lw); hold on;
    errorbar(sig,mean(rmsL_d,2),std(rmsL_d,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(1)=plot(sig-0.02,mean(rmsL_s,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on%,
    L(2)=plot(sig,mean(rmsL_d,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    ylabel('lateral RMSE [deg]')
    yline(mean(met.emp.s.rmsL),'--','Color',c1,'LineWidth',lw)
    yline(mean(met.emp.d.rmsL),'--','Color',c2,'LineWidth',lw)
    rectangle('Position',[-0.5 mean(met.emp.s.rmsL)-std(met.emp.s.rmsL) 16 2*std(met.emp.s.rmsL)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[-0.5 mean(met.emp.d.rmsL)-std(met.emp.d.rmsL) 16 2*std(met.emp.d.rmsL)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    legend('M-Stat','M-Dyn','B-Stat','B-Dyn','Location','northwest')
    ylim([0,10]);
    xlim([-0.5,15.5])
    
    subplot(4,2,5)
    errorbar(sig-0.02,mean(rmsP_s,2),std(rmsP_s,[],2),'Color',c1,'LineWidth',lw); hold on;
    errorbar(sig,mean(rmsP_d,2),std(rmsP_d,[],2),'Color',c2,'LineWidth',lw); hold on;
    plot(sig-0.02,mean(rmsP_s,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on
    plot(sig,mean(rmsP_d,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    ylabel('polar RMSE [deg]')
    yline(mean(met.emp.s.rmsP),'--','Color',c1,'LineWidth',lw)
    yline(mean(met.emp.d.rmsP),'--','Color',c2,'LineWidth',lw)
    rectangle('Position',[-0.5 mean(met.emp.s.rmsP)-std(met.emp.s.rmsP) 16 2*std(met.emp.s.rmsP)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[-0.5 mean(met.emp.d.rmsP)-std(met.emp.d.rmsP) 16 2*std(met.emp.d.rmsP)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylim([15,30]);
    xlim([-0.5,15.5])
    
    subplot(4,2,7)
    errorbar(sig-0.02,mean(querr_s,2),std(querr_s,[],2),'Color',c1,'LineWidth',lw); hold on;
    errorbar(sig,mean(querr_d,2),std(querr_d,[],2),'Color',c2,'LineWidth',lw); hold on;
    L=plot(sig-0.02,mean(querr_s,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on
    L=plot(sig,mean(querr_d,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    yline(mean(met.emp.s.querr),'--','Color',c1,'LineWidth',lw)
    yline(mean(met.emp.d.querr),'--','Color',c2,'LineWidth',lw)
    rectangle('Position',[-0.5 mean(met.emp.s.querr)-std(met.emp.s.querr) 16 2*std(met.emp.s.querr)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[-0.5 mean(met.emp.d.querr)-std(met.emp.d.querr) 16 2*std(met.emp.d.querr)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylabel('QE rate [%]')
    ylim([0,15]);
    xlim([-0.5,15.5])
    
    xlabel('\sigma_H [deg]')

    % RIGHT PLOT (sig_u=2)
    
    rmsL_s=met.mod.s.rmsL(2:2:end,:); %even indices
    rmsL_d=met.mod.d.rmsL(2:2:end,:);
    rmsP_s=met.mod.s.rmsP(2:2:end,:);
    rmsP_d=met.mod.d.rmsP(2:2:end,:);
    querr_s=met.mod.s.querr(2:2:end,:);
    querr_d=met.mod.d.querr(2:2:end,:);

    subplot(4,2,4)
    errorbar(sig-0.02,mean(rmsL_s,2),std(rmsL_s,[],2),'Color',c1,'LineWidth',lw); hold on;
    errorbar(sig,mean(rmsL_d,2),std(rmsL_d,[],2),'Color',c2,'LineWidth',lw); hold on;
    L(1)=plot(sig-0.02,mean(rmsL_s,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on%,
    L(2)=plot(sig,mean(rmsL_d,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    ylabel('lateral RMSE [deg]')
    yline(mean(met.emp.s.rmsL),'--','Color',c1,'LineWidth',lw)
    yline(mean(met.emp.d.rmsL),'--','Color',c2,'LineWidth',lw)
    rectangle('Position',[-0.5 mean(met.emp.s.rmsL)-std(met.emp.s.rmsL) 16 2*std(met.emp.s.rmsL)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[-0.5 mean(met.emp.d.rmsL)-std(met.emp.d.rmsL) 16 2*std(met.emp.d.rmsL)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    %legend(L,'M.S.','M.D.','B.S.','B.D.')
    ylim([0,10]);
    xlim([-0.5,15.5])
    
    subplot(4,2,6)
    errorbar(sig-0.02,mean(rmsP_s,2),std(rmsP_s,[],2),'Color',c1,'LineWidth',lw); hold on;
    errorbar(sig,mean(rmsP_d,2),std(rmsP_d,[],2),'Color',c2,'LineWidth',lw); hold on;
    plot(sig-0.02,mean(rmsP_s,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on
    plot(sig,mean(rmsP_d,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    ylabel('polar RMSE [deg]')
    yline(mean(met.emp.s.rmsP),'--','Color',c1,'LineWidth',lw)
    yline(mean(met.emp.d.rmsP),'--','Color',c2,'LineWidth',lw)
    rectangle('Position',[-0.5 mean(met.emp.s.rmsP)-std(met.emp.s.rmsP) 16 2*std(met.emp.s.rmsP)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[-0.5 mean(met.emp.d.rmsP)-std(met.emp.d.rmsP) 16 2*std(met.emp.d.rmsP)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylim([15,30]);
    xlim([-0.5,15.5])
    
    subplot(4,2,8)
    errorbar(sig-0.02,mean(querr_s,2),std(querr_s,[],2),'Color',c1,'LineWidth',lw); hold on;
    errorbar(sig,mean(querr_d,2),std(querr_d,[],2),'Color',c2,'LineWidth',lw); hold on;
    L=plot(sig-0.02,mean(querr_s,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw); hold on
    L=plot(sig,mean(querr_d,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw); 
    yline(mean(met.emp.s.querr),'--','Color',c1,'LineWidth',lw)
    yline(mean(met.emp.d.querr),'--','Color',c2,'LineWidth',lw)
    rectangle('Position',[-0.5 mean(met.emp.s.querr)-std(met.emp.s.querr) 16 2*std(met.emp.s.querr)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[-0.5 mean(met.emp.d.querr)-std(met.emp.d.querr) 16 2*std(met.emp.d.querr)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    ylabel('QE rate [%]')
    ylim([0,15]);
    xlim([-0.5,15.5])
    xlabel('\sigma_H [deg]')
elseif strcmp(fig,'fig6') 
    pr=[10,20,30,40,50,60];   
    figure;
    subplot(2,1,1)
    plot(pr-0.1,mean(met.mod.s.gain,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw);hold on;
    yline(mean(met.emp.s.gain),'--','Color',c1,'LineWidth',lw);
    plot(pr,mean(met.mod.d.gain,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw);
    yline(mean(met.emp.d.gain),'--','Color',c2,'LineWidth',lw);
    errorbar(pr-0.1,mean(met.mod.s.gain,2),std(met.mod.s.gain,[],2),'Color',c1,'LineWidth',lw); 
    errorbar(pr,mean(met.mod.d.gain,2),std(met.mod.d.gain,[],2),'Color',c2,'LineWidth',lw);
    rectangle('Position',[9.5 mean(met.emp.s.gain)-std(met.emp.s.gain) 51 2*std(met.emp.s.gain)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    rectangle('Position',[9.5 mean(met.emp.d.gain)-std(met.emp.d.gain) 51 2*std(met.emp.d.gain)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    legend('M-Stat','B-Stat','M-Dyn','B-Dyn','Location','southeast')
    ylabel('elevation gain')
    ylim([0,1])
    xlim([9.5,60.5]) 

    subplot(2,1,2)
    errorbar(pr-0.1,mean(met.mod.s.querr,2),std(met.mod.s.querr,[],2),'Color',c1,'LineWidth',lw); hold on;
    plot(pr-0.1,mean(met.mod.s.querr,2),'.-','MarkerSize',15,'Color',c1,'LineWidth',lw);
    yline(mean(met.emp.s.querr),'--','Color',c1,'LineWidth',lw);
    rectangle('Position',[9.5 mean(met.emp.s.querr)-std(met.emp.s.querr) 51 2*std(met.emp.s.querr)],'FaceColor',[c1,0.1],'EdgeColor',c1)
    errorbar(pr,mean(met.mod.d.querr,2),std(met.mod.d.querr,[],2),'Color',c2,'LineWidth',lw); hold on;
    plot(pr,mean(met.mod.d.querr,2),'.-','MarkerSize',15,'Color',c2,'LineWidth',lw);
    yline(mean(met.emp.d.querr),'--','Color',c2,'LineWidth',lw);
    rectangle('Position',[9.5 mean(met.emp.d.querr)-std(met.emp.d.querr) 51 2*std(met.emp.d.querr)],'FaceColor',[c2,0.1],'EdgeColor',c2)
    xlim([9.5,60.5]) 
    ylim([0,15])
    ylabel('QE rate [%]')
    xlabel('\sigma_p [deg]')

elseif strcmp(fig,'fig7') 

    %% Kent plot
    hold on;
    colormap([1 1 1]);
    set(gca,'Visible','off');
    
    % draw a sphere
    daz=30;
    AZgrid=repmat((-90:90),length(-180:daz:180),1)'*pi/180; 
    ELgrid=repmat((-180:daz:180)',1,length(-90:90))'*pi/180; 
    [xgrid1,zgrid1,ygrid1]=sph2cart(AZgrid,ELgrid,1);
    [xgrid2,zgrid2,ygrid2]=sph2cart(ELgrid,AZgrid,1);
    plot3(xgrid1,ygrid1,zgrid1,'Color',[.7 .7 .7]);
    hold on
    plot3(xgrid2,ygrid2,zgrid2,'Color',[.7 .7 .7]);
    view(90,0);
    
    scatter3(dirs(:,1),dirs(:,2),dirs(:,3),30,'xk'); 		% plot target locations
    %plot bias
    q1=quiver3(dirs(:,1),dirs(:,2),dirs(:,3),met.bias_perdir(:,1)-dirs(:,1),met.bias_perdir(:,2)-dirs(:,2),met.bias_perdir(:,3)-dirs(:,3),'off','Color','k');
    q1.MaxHeadSize = 0.05;
    q1.LineWidth = 1.5;
    % plot kent distributions
    for i=1:size(dirs,1) 
    p=fill3(met.kentdist(i,:,1),met.kentdist(i,:,2),met.kentdist(i,:,3),'k');
    p.FaceAlpha = 0.1;
    end
    
    xPlane = [0 0 0 0]; yPlane =[-1,1,1,-1] ; zPlane = [-1,-1,1,1];
    patch(xPlane, yPlane, zPlane, 'w');
    xPlane = [-1,1,1,-1]; yPlane =[0 0 0 0] ; zPlane = [-1,-1,1,1];
    patch(xPlane, yPlane, zPlane, 'w');
    
    axis equal
    daspect([1 1 1]);
    pbaspect([1 1 1]);

end
end

% %% UDC plot
% figure;
% plot3(xgrid1,ygrid1,zgrid1,'Color',[.7 .7 .7]);
% hold on
% plot3(xgrid2,ygrid2,zgrid2,'Color',[.7 .7 .7]);
% view(90,0);
% 
% scatter3(dirs(:,1),dirs(:,2),dirs(:,3),600,met.udc_perdir(:),'filled');
% cmap=colormap("bone");
% colormap(flipud(cmap))
% caxis([0 40])
% colorbar("southoutside")
% scatter3(dirs(:,1),dirs(:,2),dirs(:,3),50,'k','Marker','x','LineWidth',1);
% title('up-down confusions');
% 
% axis off
% ylim([-1,1]);
% axis equal

function [Theta_H,y_H,mu_H]=kalmanfilter(sig_H,sig_u)
    rng('default')
    delta_H=chol(sig_H^2)*randn([30,2]); %noise on measurement
    delta_u=chol(sig_u^2)*randn([30,2]); %noise on motor control
    
    % noise on head rotation angle sequence
    sig_head2 = zeros(1,20);
    sig_head2(1) = sig_H^2;
    Theta_H=zeros(20,2);
    mu_H=zeros(20,2);
    y_H=zeros(20,2);
    y_H(1,:)=delta_H(1,:);
    mu_H(1,:)=y_H(1,:);
    
    for t=1:19
    K(t) = (sig_head2(t) + sig_u^2) / (sig_head2(t) + sig_u^2 + sig_H^2); %Kalman filter
    sig_head2(t+1)=(1-K(t))*(sig_head2(t)+sig_u^2);
    
    Theta_H(t+1,:)=Theta_H(t,:)+delta_u(t,:);
    y_H(t+1,:)=Theta_H(t+1,:)+delta_H(t,:); %[M,2] noisy measurement of head orientations
    mu_H(t+1,:)=(1-K(t))*(mu_H(t,:))+K(t)*y_H(t+1,:); % estimate of true head orientation using Kalman filter
    
    end
end


