%
% Convert measured current TM-->physical units?
%
function I2=Calibrate_cnt_cur(SC,I1)

I2=I1; % Default if none of the projects below are recognized.

if(strcmp(SC.PRO,'Cassini'))
  I2 = CalLP_Cassini(I1);
end

end