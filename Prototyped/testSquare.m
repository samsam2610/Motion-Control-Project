time = linspace(0, 0.05,1000);
frequency = 100;

dutycycle = 20;
delay = 0.5*(dutycycle/100)*1/100;
time_y1 = time - delay;
y = 0.5*square(2*pi*100*time, 20) + 0.5;
plot(time_y1, y)
hold on

dutycycle = 1;
delay = 0.5*(dutycycle/100)*1/100;
time_y2 = time - delay;
y2 = 0.5*square(2*pi*100*time, 1) + 0.5;
plot(time, y2)