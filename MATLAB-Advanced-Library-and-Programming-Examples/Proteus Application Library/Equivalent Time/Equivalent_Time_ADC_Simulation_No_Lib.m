numOfSymbols =          2^13;
numOfAcquisitions =     100;
adcSampleRate =         2.7E9;
symbolRate =            10.0E9;
wfmBW =                 1.0;
clkFactor =             256;
simulFact =             1231;
timeWindow =            200E-12;

numOfBins =             500;
numOfLvls =             256;
voltRange =             4.0;

myDisplay = zeros(numOfBins, numOfLvls);

% Clock Waveform
myClk = 0:(numOfSymbols - 1);
myClk = mod(myClk, clkFactor);
myClk = myClk - clkFactor / 2;
myClk(myClk >= 0) = 1;
myClk(myClk < 0) = -1;

% Wavefortm Exapnsion
simulSr = symbolRate * simulFact;
dataExpanFactor = round(simulSr / symbolRate);

finalClk = zeros(1, numOfSymbols * dataExpanFactor);

for i = 0:(dataExpanFactor - 1)
    finalClk((i+1):dataExpanFactor:length(finalClk)) = myClk;
end

% Align edge with center of the symbol
finalClk = circshift(finalClk , round(dataExpanFactor / 2));
finalClk = myLpFilter(finalClk, symbolRate / clkFactor, simulSr) ;

% Decimation for sampling at nominal speed
decimFactor = round(simulSr / adcSampleRate);

finalClk = finalClk(1:decimFactor:length(finalClk));

% Zero cross detection for clock waveform
xValues = double.empty;

for i = 2:(length(finalClk) - 1)
    if (finalClk(i) <= 0.0 && finalClk(i + 1) >= 0.0)
        xCross = GetCrossing(finalClk(i - 1), finalClk(i), finalClk(i + 1), 0.0); 
        xValues = [xValues, (i + xCross)]; 
    elseif (finalClk(i) >= 0.0 && finalClk(i + 1) <= 0.0)
        xCross = GetCrossing(finalClk(i - 1), finalClk(i), finalClk(i + 1), 0.0); 
        xValues = [xValues, (i + xCross)];  
    end
end

% Interpolation of clock edges
xValues = ClockInterp(xValues, clkFactor / 2);

eyeX = zeros(1, length(xValues));
eyeY = zeros(1, length(xValues));

imageX = [1:numOfBins];
imageX = imageX - length(imageX) / 2;
imageX = imageX * timeWindow / numOfBins;
imageY = [1:numOfLvls];

for acqNum = 1:numOfAcquisitions
    
    eyePtr = 0;

    % Waveform Creation
    % =================
    % NRZ waveform
    myWfm = rand(1, numOfSymbols);
    myWfm(myWfm > 0.5) = 2;
    myWfm(myWfm <= 0.5) = 0;
    myWfm = myWfm - 1;

    finalWfm = zeros(1, numOfSymbols * dataExpanFactor);
    
    for i = 0:(dataExpanFactor - 1)
        finalWfm((i+1):dataExpanFactor:length(finalWfm)) = myWfm;
    end   

    % Waveform filtering to the target bandwidth
    finalWfm = myLpFilter(finalWfm,symbolRate * wfmBW ,simulSr) ;

    % Decimation for sampling at nominal speed
    finalWfm = finalWfm(1:decimFactor:length(finalWfm));
        
    sPeriod = 1 / adcSampleRate; 

    for i = 1:length(xValues)    
        j = floor(xValues(i));
        for k = -0:1
            if (j+k) >= 1 && (j+k) <= length(finalWfm)
                deltaT = j + k - xValues(i);
                deltaT = deltaT / adcSampleRate;
                if abs(deltaT) <= timeWindow / 2
                    eyePtr = eyePtr + 1;
                    eyeX(eyePtr) = deltaT;
                    eyeY(eyePtr)= finalWfm(j + k);
                end
            end
        end    
    end
    
    cX = round(numOfBins / 2 + numOfBins * eyeX(1:eyePtr) / timeWindow);
    cX = cX + 1;
    cX(cX < 1) = 1;
    cX(cX > numOfBins) = numOfBins;
    
    cY = round(numOfLvls / 2 + numOfLvls * eyeY(1:eyePtr) / voltRange);
    cY = cY + 1;
    cY(cY < 1) = 1;
    cY(cY > numOfLvls) = numOfLvls;
      
    for i = 1:length(cX)
        myDisplay(cX(i), cY(i)) = myDisplay(cX(i), cY(i)) + 1;
    end
    
    imagesc(imageX, imageY, myDisplay');
    colorbar;
    drawnow;
end

% myDisplay = 100 + myDisplay;
% surf(myDisplay);
% hold on;
% imagesc(myDisplay);


% imagesc(imageX,imageY,myDisplay');
% colorbar;


%scatter(eyeX, eyeY, '.');

% plot(finalWfm);
% hold;
% plot(finalClk);

function xCross = GetCrossing(y1, y2, y3, yCross)

    a = (y1 + y3 - 2*y2) / 2;
    b = (y3 - y1) / 2;
    c = y2;
    
    c = c - yCross;    
    e = sqrt(b*b - 4 * a * c);    
    xCross = (- b + e) / (2 * a) ;
    
    if abs(xCross) > 1.0
        xCross = (- b - e) / (2 * a);        
    end   
end

function interpClock = ClockInterp(inputClock, intFactor)

    interpClock = zeros(1, intFactor * (length(inputClock) - 1) + 1);
    
    for i = 0: (length(inputClock) - 2)
        for j = 0:(intFactor - 1)
            interpClock(intFactor * i + j + 1) = inputClock(i + 1) + j *...
                (inputClock(i + 2) - inputClock(i + 1))/intFactor;            
        end        
    end
    
    interpClock(length(interpClock)) = inputClock(length(inputClock));
end


function filteredX = myLpFilter(x, fCut, fS)

    filterLength = 20 * (fS/fCut);
    filterLength = round(filterLength);
    if mod(filterLength, 2) == 0
        filterLength = filterLength + 1;
    end
    myFilter = -floor(filterLength / 2):floor(filterLength / 2);
    myFilter = sinc(2 * fCut / fS * myFilter);
    
    myFilter = myFilter / sum(myFilter);
    
    filteredX = cconv(x,myFilter,length(x));
end