classdef EFISApp < handle


    properties
        UIFigure
        UIAxes
        StartButton
        StopButton
        PitchSlider
        RollSlider

        % Graphics handles
        sky
        ground
        horizon
        pitchLines
        pitchTexts
        rollArc
        rollTicks
        rollPointer
        bankIndicator
        fpvBody
        fpvWings
        hdgText
        fmaText
        speedBox
        speedValueText
        speedTicks
        speedTexts
        altBox
        altValueText
        altTicks
        altTexts
        vsiBox
        vsiBar
        vsiText
    end

    properties (Access = private)
        timerObj
        pitch = 0
        roll = 0
        rollDisplay = 0
        heading = 90
        speed = 145
        altitude = 1500
        vsi = 0
        sideslip = 0
        stopFlag = true
        tapeTickRange = -40:5:40
        tapeTickSpacing = 0.025
    end

    methods
        function app = EFISApp()
            app.buildUI();
            app.drawBase();
            app.setupTimer();
        end

        function delete(app)
            try
                stop(app.timerObj);
                delete(app.timerObj);
            end
            delete(app.UIFigure);
        end
    end

    methods (Access = private)
        %% ---------- UI ----------
        function buildUI(app)
            app.UIFigure = uifigure('Name','Airbus PFD',...
                'Color',[0.05 0.05 0.05],'Position',[200 100 1100 770]);

            app.UIAxes = uiaxes(app.UIFigure,'Position',[140 180 820 460]);
            axis(app.UIAxes,[-2 2 -1.4 1.6]);
            app.UIAxes.Color = [0.1 0.1 0.1];
            app.UIAxes.XColor = 'none';
            app.UIAxes.YColor = 'none';
            hold(app.UIAxes,'on');

            app.StartButton = uibutton(app.UIFigure,'Text','Start',...
                'Position',[180 80 110 36],'ButtonPushedFcn',@(s,e)app.startSim());
            app.StopButton = uibutton(app.UIFigure,'Text','Stop',...
                'Position',[310 80 110 36],'ButtonPushedFcn',@(s,e)app.stopSim());

            uilabel(app.UIFigure,'Text','Pitch','FontColor','w','Position',[470 140 50 20]);
            app.PitchSlider = uislider(app.UIFigure,'Position',[520 150 360 3],...
                'Limits',[-30 30],'ValueChangedFcn',@(s,e)app.setPitch(s.Value));

            uilabel(app.UIFigure,'Text','Roll','FontColor','w','Position',[470 100 50 20]);
            app.RollSlider = uislider(app.UIFigure,'Position',[520 110 360 3],...
                'Limits',[-60 60],'ValueChangedFcn',@(s,e)app.setRoll(s.Value));
        end

        %% ---------- Base Graphics ----------
        function drawBase(app)
            ax = app.UIAxes; cla(ax); hold(ax,'on');

            % Sky & Ground
            app.sky = patch(ax,[-2 2 2 -2],[0 0 2 2],[0.27 0.62 1],'EdgeColor','none');
            app.ground = patch(ax,[-2 2 2 -2],[0 0 -2 -2],[0.55 0.28 0.06],'EdgeColor','none');
            app.horizon = plot(ax,[-2 2],[0 0],'w','LineWidth',2);

            % Pitch ladder
            pitchMarks = -30:2.5:30;
            mainMarks = -30:10:30; mainMarks(mainMarks==0) = [];
            for i=1:length(pitchMarks)
                app.pitchLines(i) = plot(ax,NaN,NaN,'w','LineWidth',1.2);
            end
            for i=1:length(mainMarks)
                app.pitchTexts(i) = text(ax,NaN,NaN,'','Color','w','FontSize',13,...
                    'FontWeight','bold','HorizontalAlignment','center');
            end

            % Roll arc
            t = linspace(-pi/3,pi/3,160);
            app.rollArc = plot(ax,1.35*sin(t),1.32+0.09*cos(t),'w','LineWidth',1.6);
            tickAngles = [-60 -45 -30 -20 -10 0 10 20 30 45 60];
            for k = 1:length(tickAngles)
                th = deg2rad(tickAngles(k));
                x1 = 1.35*sin(th); y1 = 1.32 + 0.09*cos(th);
                x2 = 1.35*sin(th); y2 = 1.32 + 0.06*cos(th);
                app.rollTicks(k) = plot(ax,[x1 x2],[y1 y2],'w','LineWidth',1.4);
            end
            app.rollPointer = plot(ax,[0 0],[1.35 1.48],'y','LineWidth',3);
            app.bankIndicator = fill(ax,[-0.03 0.03 0],[1.0 1.0 1.06],'y','EdgeColor','none');

            % FPV (Flight Path Vector)
            app.fpvBody = plot(ax,[0 0],[0 0],'Color',[0 1 0],'LineWidth',2);
            app.fpvWings = plot(ax,[0 0],[0 0],'Color',[0 1 0],'LineWidth',2);

            % Speed tape (boxed Airbus style)
            app.speedBox = rectangle(ax,'Position',[-1.35 -0.15 0.27 0.3],...
                'FaceColor',[0 0 0],'EdgeColor','w','LineWidth',1.5);
            fill(ax,[-1.35 -1.08 -1.08 -1.35],[-0.15 -0.15 0.15 0.15],[0 0.2 0],'EdgeColor','none');
            app.speedValueText = text(ax,-1.215,0,'145','Color','w','FontSize',18,...
                'FontWeight','bold','HorizontalAlignment','center');
            nt = length(app.tapeTickRange);
            for i=1:nt
                app.speedTicks(i) = plot(ax,NaN,NaN,'w','LineWidth',1);
                app.speedTexts(i) = text(ax,NaN,NaN,'','Color','w','FontSize',9,'HorizontalAlignment','center');
            end

            % Altitude tape (boxed Airbus style)
            app.altBox = rectangle(ax,'Position',[1.08 -0.15 0.27 0.3],...
                'FaceColor',[0 0 0],'EdgeColor','w','LineWidth',1.5);
            fill(ax,[1.08 1.35 1.35 1.08],[-0.15 -0.15 0.15 0.15],[0 0.2 0],'EdgeColor','none');
            app.altValueText = text(ax,1.225,0,'01500','Color','w','FontSize',18,...
                'FontWeight','bold','HorizontalAlignment','center');
            for i=1:nt
                app.altTicks(i) = plot(ax,NaN,NaN,'w','LineWidth',1);
                app.altTexts(i) = text(ax,NaN,NaN,'','Color','w','FontSize',9,'HorizontalAlignment','center');
            end

            % VSI (Vertical Speed Indicator)
            app.vsiBox = rectangle(ax,'Position',[1.38 -0.45 0.12 0.9],...
                'FaceColor',[0.08 0.08 0.08],'EdgeColor','w','LineWidth',1.2);
            app.vsiBar = plot(ax,[1.38 1.48],[0 0],'Color',[0 1 0],'LineWidth',3);
            app.vsiText = text(ax,1.44,0,'0','Color','w','FontSize',10,...
                'HorizontalAlignment','center');

            % Flight Mode Annunciator (top cyan)
            app.fmaText = text(ax,0,1.45,'A/THR  |  HDG  |  ALT','Color',[0 1 1],...
                'FontSize',13,'FontWeight','bold','HorizontalAlignment','center');

            % Heading text (moved lower for clarity)
            app.hdgText = text(ax,0,-1.35,'HDG: 090°','Color','w','FontSize',15,...
                'FontWeight','bold','HorizontalAlignment','center');

            app.updateDisplay();
        end

        %% ---------- Timer ----------
        function setupTimer(app)
            app.timerObj = timer('ExecutionMode','fixedRate','Period',0.03,...
                'TimerFcn',@(~,~)app.updateSim());
        end

        function startSim(app)
            app.stopFlag = false;
            if strcmp(app.timerObj.Running,'off')
                start(app.timerObj);
            end
        end

        function stopSim(app)
            app.stopFlag = true;
        end

        %% ---------- Slider Functions ----------
        function setPitch(app,val)
            app.pitch = val;
            app.updateDisplay();
        end

        function setRoll(app,val)
            app.roll = val;
            app.updateDisplay();
        end

        %% ---------- Simulation ----------
        function updateSim(app)
            if app.stopFlag, return; end
            t = now*24*3600;
            app.pitch = 10*sin(t/6);
            app.roll = 25*sin(t/8);
            app.heading = mod(app.heading + 0.4,360);
            app.speed = 140 + 5*sin(t/7);
            app.altitude = 1500 + 80*sin(t/9);
            app.vsi = 400*sin(t/5);
            app.sideslip = 5*sin(t/4);
            app.updateDisplay();
        end

        %% ---------- Display Update ----------
        function updateDisplay(app)
            ax = app.UIAxes;
            app.rollDisplay = app.rollDisplay + 0.12*(app.roll - app.rollDisplay);
            Rmat = [cosd(app.rollDisplay) -sind(app.rollDisplay); sind(app.rollDisplay) cosd(app.rollDisplay)];

            pitchScale = 0.04;
            yshift = app.pitch * pitchScale;

            % Horizon
            X = [-2 2 2 -2];
            skyY = [yshift yshift 2 2];
            groundY = [yshift yshift -2 -2];
            s = Rmat * [X; skyY];
            g = Rmat * [X; groundY];
            set(app.sky,'XData',s(1,:),'YData',s(2,:));
            set(app.ground,'XData',g(1,:),'YData',g(2,:));
            h = Rmat * [-2 2; [yshift yshift]];
            set(app.horizon,'XData',h(1,:),'YData',h(2,:));

            % Pitch ladder
            allMarks = -30:2.5:30;
            mainMarks = -30:10:30; mainMarks(mainMarks==0)=[];

            idx = 1;
            for ang = allMarks
                y = (ang - app.pitch)*pitchScale;
                len = 0.6; lw = 1;
                if mod(ang,10)==0, lw=2; len=0.8; end
                pts = Rmat * [-len len; y y];
                set(app.pitchLines(idx),'XData',pts(1,:),'YData',pts(2,:),'LineWidth',lw);
                idx = idx + 1;
            end
            for i=1:length(mainMarks)
                ang = mainMarks(i);
                y = (ang - app.pitch)*pitchScale;
                pos = Rmat * [0; y];
                set(app.pitchTexts(i),'Position',[pos(1) pos(2) 0],'String',sprintf('%+d°',ang));
            end

            % Roll pointer
            rp = deg2rad(app.rollDisplay);
            set(app.rollPointer,'XData',[0 1.35*sin(rp)],'YData',[1.35 1.32+0.09*cos(rp)]);

            % FPV (Flight Path Vector)
            fpv_y = -app.pitch*pitchScale*0.9;
            fpv_x = 0.01*app.sideslip;
            set(app.fpvBody,'XData',[fpv_x fpv_x],'YData',[fpv_y-0.03 fpv_y+0.03]);
            set(app.fpvWings,'XData',[fpv_x-0.05 fpv_x+0.05],'YData',[fpv_y fpv_y]);

            % Speed tape
            centerSpeed = round(app.speed);
            set(app.speedValueText,'String',sprintf('%03d',centerSpeed));
            nt = length(app.tapeTickRange);
            for i=1:nt
                rel = app.tapeTickRange(i);
                val = centerSpeed + rel;
                y = -rel * app.tapeTickSpacing;
                set(app.speedTicks(i),'XData',[-1.12 -1.05],'YData',[y y]);
                set(app.speedTexts(i),'Position',[-1.22 y 0],'String',sprintf('%03d',val));
            end

            % Altitude tape
            centerAlt = round(app.altitude);
            set(app.altValueText,'String',sprintf('%05d',centerAlt));
            for i=1:nt
                rel = app.tapeTickRange(i);
                val = centerAlt + rel*10;
                y = -rel * app.tapeTickSpacing;
                set(app.altTicks(i),'XData',[1.05 1.12],'YData',[y y]);
                set(app.altTexts(i),'Position',[1.225 y 0],'String',sprintf('%05d',val));
            end

            % VSI
            vsiNorm = max(min(app.vsi/1000,1),-1);
            set(app.vsiBar,'YData',[0 vsiNorm*0.4]);
            set(app.vsiText,'String',sprintf('%+d',round(app.vsi)));

            % Heading display
            set(app.hdgText,'String',sprintf('HDG: %03d°',round(app.heading)));

            drawnow limitrate nocallbacks;
        end
    end
end
