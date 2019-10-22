classdef ExperimentsData < handle
    %Class for handling experiment data from an MERID triaxial experiment. The class
    %is able to get a database dump directly from the MySQL database and
    %handle it.
    %IMPORTANT:
    %This class is directly dependent on the structure of the database. The 
    %names of the table columns are accessed so that they must not be
    %changed. If the names are changed the function organizeTableData() has
    %to be adapted with new names.
    %
    %It is possible to get specific experiment data instead of the whole
    %table.
    %
    % 2019-05-16 Biebricher
    %   * Bugfix getFlowData(): Changed fluid_t to fluidOutTemp
    % 2019-05-14 Biebricher
    %   * Creator changed to work with fluid temperature in and out seperate
    %   * Changed getAllTemperatures(): Missing data will be filled up by a
    %       linear interpolation between two neighbors.
    % 2019-05-13 Biebricher
    %   * Changed name from 'getChamberPumpData' to 'getBassinPumpData'
    %   * Added some more unit information to datatable
    % 2019-06-28 Hiestermann
    %   *Added Calculation Table 
    %   *Added getPermeability function
    %   *Added Analytics Table
    % 2019-08-09 Biebricher
    %   *Changed all table-variables to timetable-variables
    %   *Include checks for all input parameters for all functions
    %   *Adding some aditional comments in code
    %   *Deprecated function getCalculationData
    %   *Adding function waterDensity(T), extracted from getCalculationData
    %   *Refactoring getPermeability
    %   *Refactoring getAnalytics to getAnalyticsDataForGUI
    %   *Added function organizeTableData(data) to check the consistence of
    %       the given data stream and add additional information like units
    %       and description. Data conversion from table to timetable
    % 2019-08-15 Hiestermann
    %   *Added deformation deviation to getAnalyticsDataforGUI
    % 2019-08-30 Hiestermann
    %   *Added mean filter to getAllPressureRelative; window of 20 for
    %   fluid pressure, window of 50 for confining pressure and pressure of hydraulic
    %   cylinder 
    % 2019-09-03 Hiestermann
    %   *Added median filter to getAllTemperature; 
    %   *Added median filter to getDeformationRelative
    % 2019-09-06 Biebricher
    %   *Added filterTableData() as a function to filter the data once
    %       globaly. All other function adapted.
    %   *Added showDebugPlotSingle() as function to plot all datasets
    %       modified by filterTableData()
    %   *Deprecated function getconfiningPressureRelative(). Use
    %       getConfiningPressure().
    %   *Fixed issues with VariableUnits and VariableDescription
    %   *Changed access to 'private' for organizeTableData() and
    %       filterTableData().
    %   *Changed access to private for dataTables
    % 2019-09-09 Biebricher
    %   * getPermeability() added check if diameter or length are NaN
    % 2019-09-30 Biebricher
    %   * getPermeability() add debug mode: output all parameters
    %   * getPermeability() prohibit negative flowMass differences and
    %                       replace by 0
    % 2019-10-21
    %   * organizeTableData() fixed to work with timetable as input
    %       (instead of table). Check if a row exists, otherwise creating
    %       the row and filling with NaN. Not used datasets like timestamp
    %       deleted.
    % 2019-10-22
    %   * organizeTableData() solved retime issues with NaN-entry-only colums
    %   * all variables in camel case
    %   * renaming all columns in timetables
    
    properties (SetAccess = immutable)%, GetAccess = private)
        originalData; %Dataset as timetable
        filteredData; %Filtered dataset as timetable
    end
    
    properties (SetAccess = immutable)
        experimentNo; %Experiment number of the data
        rows;         %Number of entries on originalData/filteredData
    end
    
    methods (Access = private)
        function dataTable = organizeTableData(obj, data)
        %This function is used to have specific names for each column, even
        %if the names in the database and therefore in the incomming data
        %stream changed. Additionaly the units, names and descriptions of
        %the columns will be added.
        
            %Check if all columns are present and add units and description
            try
                %Initializing the timetable
                dataTable = timetable(data.time);
                dataTable.Properties.DimensionNames{1} = 'datetime';  
                dataTable.datetime.Format = ('yyyy-MM-dd HH:mm:ss.SSS');
                
                vD.roomTemp = 'continuous';
                vD.roomPressureAbs= 'continuous';
                vD.fluidInTemp= 'continuous';
                vD.fluidOutTemp= 'continuous';
                vD.fluidPressureAbs= 'continuous';
                vD.fluidPressureRel= 'continuous';
                vD.hydrCylinderPressureAbs= 'continuous';
                vD.hydrCylinderPressureRel= 'continuous';
                vD.ConfiningPressureAbs= 'continuous';
                vD.confiningPressureRel= 'continuous';
                vD.strainSensor1Pos= 'step';
                vD.strainSensor1Rel= 'step';
                vD.strainSensor2Pos= 'step';
                vD.strainSensor2Rel= 'step';
                vD.pump1Volume= 'step';
                vD.pump1PressureRel= 'continuous';
                vD.pump2Volume= 'step';
                vD.pump2PressureRel= 'continuous';
                vD.pump3Volume= 'step';
                vD.pump3PressureRel= 'continuous';
                vD.flowMass= 'continuous';
                vD.runtime= 'continuous';
                
                %roomTemp: room temperatur
                if ismember('room_t', data.Properties.VariableNames)
                    dataTable.roomTemp = data.room_t;
                else
                    dataTable.roomTemp = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Room temperature (roomTemp) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.roomTemp)) == size(data,1) 
                    vD.roomTemp = 'unset';
                end
                dataTable.Properties.VariableUnits{'roomTemp'} = '�C';
                dataTable.Properties.VariableDescriptions{'roomTemp'} = 'Ambient air temperature';
                
                
                %roomPressureAbs: air pressure
                if ismember('room_p_abs', data.Properties.VariableNames)
                    dataTable.roomPressureAbs = data.room_p_abs;
                else
                    dataTable.roomPressureAbs = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Air pressure (roomPressureAbs) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.roomPressureAbs)) == size(data,1) 
                    vD.roomPressureAbs = 'unset';
                end
                dataTable.Properties.VariableUnits{'roomPressureAbs'} = 'bar';
                dataTable.Properties.VariableDescriptions {'roomPressureAbs'} = 'Atmospheric pressure';

                %fluidInTemp: inflow fluid temperature
                if ismember('fluid_in_t', data.Properties.VariableNames)
                    dataTable.fluidInTemp = data.fluid_in_t;
                else
                    dataTable.fluidInTemp = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Fluid inflow temperatur (fluidInTemp) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.fluidInTemp)) == size(data,1) 
                    vD.fluidInTemp = 'unset';
                end
                dataTable.Properties.VariableUnits{'fluidInTemp'} = '�C';
                dataTable.Properties.VariableDescriptions {'fluidInTemp'} = 'Temperature of the fluid before flowing the specimen.';

                %fluidOutTemp: outflow fluid temperature
                if ismember('fluid_out_t', data.Properties.VariableNames)
                    dataTable.fluidOutTemp = data.fluid_out_t;
                else
                    dataTable.fluidOutTemp = NaN(size(data,1),1);
                end
                if sum(isnan(dataTable.fluidOutTemp)) == size(data,1)
                    vD.fluidOutTemp = 'unset';
                    warning([class(obj), ' - ', 'Fluid outflow temperatur (fluidOutTemp) data missing. Added column filled with NaN. Permeabilitycalculation will be imprecisely.']);;
                end
                dataTable.Properties.VariableUnits{'fluidOutTemp'} = '�C';
                dataTable.Properties.VariableDescriptions {'fluidOutTemp'} = 'Temperature of the fluid after flowing through, meassured on the scale.';

                %fluidPressureAbs: abslute fluid pressure
                if ismember('fluid_p_abs', data.Properties.VariableNames)
                    dataTable.fluidPressureAbs = data.fluid_p_abs;
                else
                    dataTable.fluidPressureAbs = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Fluid flow absolute pressure (fluidPressureAbs) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.fluidPressureAbs)) == size(data,1) 
                    vD.fluidPressureAbs = 'unset';
                end
                dataTable.Properties.VariableUnits{'fluidPressureAbs'} = 'bar';
                dataTable.Properties.VariableDescriptions {'fluidPressureAbs'} = 'Inflow pressure specimen (absolute value)';

                %fluidPressureRel: relative fluid pressure
                if ismember('fluid_p_rel', data.Properties.VariableNames)
                    dataTable.fluidPressureRel = data.fluid_p_rel;
                else
                    dataTable.fluidPressureRel = NaN(size(data,1),1);
                end
                if sum(isnan(dataTable.fluidPressureRel)) == size(data,1)
                    vD.fluidPressureRel = 'unset';
                    warning([class(obj), ' - ', 'Fluid flow relative pressure (fluidPressureRel) data missing. Permeability calculation not possible!']);
                end
                dataTable.Properties.VariableUnits{'fluidPressureRel'} = 'bar';
                dataTable.Properties.VariableDescriptions {'fluidPressureRel'} = 'Inflow pressure specimen (relative value)';
                
                %hydrCylinderPressureAbs: absolute hydraulic cylinder pressure
                if ismember('hydrCylinder_p_abs', data.Properties.VariableNames)
                    dataTable.hydrCylinderPressureAbs = data.hydrCylinder_p_abs;
                else
                    dataTable.hydrCylinderPressureAbs = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Hydraulic cynlinder absolute pressure (hydrCylinderPressureAbs) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.hydrCylinderPressureAbs)) == size(data,1) 
                    vD.hydrCylinderPressureAbs = 'unset';
                end
                dataTable.Properties.VariableUnits{'hydrCylinderPressureAbs'} = 'bar';
                dataTable.Properties.VariableDescriptions {'hydrCylinderPressureAbs'} = 'Operating pressure of the hydraulic cylinder (absolue value)';

                %hydrCylinderPressureRel: relative hydraulic cylinder pressure
                if ismember('hydrCylinder_p_rel', data.Properties.VariableNames)
                    dataTable.hydrCylinderPressureRel = data.hydrCylinder_p_rel;
                else
                    dataTable.hydrCylinderPressureRel = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Hydraulic cynlinder relative pressure (hydrCylinderPressureRel) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.hydrCylinderPressureRel)) == size(data,1) 
                    vD.hydrCylinderPressureRel = 'unset';
                end
                dataTable.Properties.VariableUnits{'hydrCylinderPressureRel'} = 'bar';
                dataTable.Properties.VariableDescriptions {'hydrCylinderPressureRel'} = 'Operating pressure of the hydraulic cylinder (relative value)';
                
                %ConfiningPressureAbs: absolute confining pressure
                if ismember('sigma2_3_p_abs_1', data.Properties.VariableNames)
                    dataTable.ConfiningPressureAbs = data.sigma2_3_p_abs_1;
                else
                    dataTable.ConfiningPressureAbs = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Confining absolute pressure (ConfiningPressureAbs) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.ConfiningPressureAbs)) == size(data,1) 
                    vD.ConfiningPressureAbs = 'unset';
                end
                dataTable.Properties.VariableUnits{'ConfiningPressureAbs'} = 'bar';
                dataTable.Properties.VariableDescriptions {'ConfiningPressureAbs'} = 'Confining pressure in the bassin. Meassured at the inflow pipe (absolute value)';

                %confiningPressureRel: relative confining pressure
                if ismember('sigma2_3_p_rel_1', data.Properties.VariableNames)
                    dataTable.confiningPressureRel = data.sigma2_3_p_rel_1;
                else
                    dataTable.confiningPressureRel = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Confining relative pressure (confiningPressureRel) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.confiningPressureRel)) == size(data,1) 
                    vD.confiningPressureRel = 'unset';
                end
                dataTable.Properties.VariableUnits{'confiningPressureRel'} = 'bar';
                dataTable.Properties.VariableDescriptions {'confiningPressureRel'} = 'Confining pressure in the bassin. Meassured at the inflow pipe (relative value)';
                
                %strainSensor1Pos: absolute deformation sensor 1
                if ismember('deformation_1_s_abs', data.Properties.VariableNames)
                    dataTable.strainSensor1Pos = data.deformation_1_s_abs;
                else
                    dataTable.strainSensor1Pos = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Absolute deformation sensor 1 (strainSensor1Pos) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.strainSensor1Pos)) == size(data,1) 
                    vD.strainSensor1Pos = 'unset';
                end
                dataTable.Properties.VariableUnits{'strainSensor1Pos'} = 'mm';
                dataTable.Properties.VariableDescriptions {'strainSensor1Pos'} = 'Absolute deformation derived from the voltage';
                
                %strainSensor1Rel: relative deformation sensor 1
                if ismember('deformation_1_s_rel', data.Properties.VariableNames)
                    dataTable.strainSensor1Rel = data.deformation_1_s_rel;
                else
                    dataTable.strainSensor1Rel = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Relative deformation sensor 1 (strainSensor1Rel) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.strainSensor1Rel)) == size(data,1) 
                    vD.strainSensor1Rel = 'unset';
                end
                dataTable.Properties.VariableUnits{'strainSensor1Rel'} = 'mm';
                dataTable.Properties.VariableDescriptions {'strainSensor1Rel'} = 'Relative deformation, zeroed at the beginning of the experiment';
                                
                %strainSensor1Pos: absolute deformation sensor 2
                if ismember('deformation_2_s_abs', data.Properties.VariableNames)
                    dataTable.strainSensor2Pos = data.deformation_2_s_abs;
                else
                    dataTable.strainSensor2Pos = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Absolute deformation sensor 2 (strainSensor2Pos) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.strainSensor2Pos)) == size(data,1) 
                    vD.strainSensor2Pos = 'unset';
                end
                dataTable.Properties.VariableUnits{'strainSensor2Pos'} = 'mm';
                dataTable.Properties.VariableDescriptions {'strainSensor2Pos'} = 'Absolute deformation derived from the voltage';
                
                %strainSensor1Rel: relative deformation sensor 2
                if ismember('deformation_2_s_rel', data.Properties.VariableNames)
                    dataTable.strainSensor2Rel = data.deformation_2_s_rel;
                else
                    dataTable.strainSensor2Rel = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Relative deformation sensor 2 (strainSensor2Rel) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.strainSensor2Rel)) == size(data,1) 
                    vD.strainSensor2Rel = 'unset';
                end
                dataTable.Properties.VariableUnits{'strainSensor2Rel'} = 'mm';
                dataTable.Properties.VariableDescriptions {'strainSensor2Rel'} = 'Relative deformation, zeroed at the beginning of the experiment';
                
                %Check if any relative deformation is given
                if sum(isnan(dataTable.strainSensor1Rel)) == size(data,1) && sum(isnan(dataTable.strainSensor2Rel)) == size(data,1)
                    warning([class(obj), ' - ', 'Deformation relative data missing (strainSensor1Rel and strainSensor2Rel) data missing. Permeability calculation not possible!']);
                end

                %pump1Volume: volume pump 1
                if ismember('pump_1_V', data.Properties.VariableNames)
                    dataTable.pump1Volume = data.pump_1_V;
                else
                    dataTable.pump1Volume = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Volume Pump 1 (pump1Volume) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.pump1Volume)) == size(data,1) 
                    vD.pump1Volume = 'unset';
                end
                dataTable.Properties.VariableUnits{'pump1Volume'} = 'ml';
                dataTable.Properties.VariableDescriptions {'pump1Volume'} = 'Liquid present in the pump';

                %pump1PressureRel: relative pressure pump 1
                if ismember('pump_1_V', data.Properties.VariableNames)
                    dataTable.pump1PressureRel = data.pump_1_V;
                else
                    dataTable.pump1PressureRel = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Pressure Pump 1 (pump1PressureRel) data missing. Added column filled with NaN.']);
                end 
                if sum(isnan(dataTable.pump1PressureRel)) == size(data,1) 
                    vD.pump1PressureRel = 'unset';
                end
                dataTable.Properties.VariableUnits{'pump1PressureRel'} = 'bar';
                dataTable.Properties.VariableDescriptions {'pump1PressureRel'} = 'Pressure measured internally in the pump (relative value)';

                %pump2Volume: volume pump 2
                if ismember('pump_2_V', data.Properties.VariableNames)
                    dataTable.pump2Volume = data.pump_2_V;
                else
                    dataTable.pump2Volume = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Volume Pump 2 (pump2Volume) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.pump2Volume)) == size(data,1) 
                    vD.pump2Volume = 'unset';
                end
                dataTable.Properties.VariableUnits{'pump2Volume'} = 'ml';
                dataTable.Properties.VariableDescriptions {'pump2Volume'} = 'Liquid present in the pump';

                %pump2PressureRel: relative pressure pump 2
                if ismember('pump_2_p', data.Properties.VariableNames)
                    dataTable.pump2PressureRel = data.pump_2_p;
                else
                    dataTable.pump2PressureRel = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Pressure Pump 2 (pump2PressureRel) data missing. Added column filled with NaN.']);
                end    
                if sum(isnan(dataTable.pump2PressureRel)) == size(data,1) 
                    vD.pump2PressureRel = 'unset';
                end
                dataTable.Properties.VariableUnits{'pump2PressureRel'} = 'bar';
                dataTable.Properties.VariableDescriptions {'pump2PressureRel'} = 'Pressure measured internally in the pump (relative value)';

                %pump3Volume: volume pump 3
                if ismember('pump_3_V', data.Properties.VariableNames)
                    dataTable.pump3Volume = data.pump_3_V;
                else
                    dataTable.pump3Volume = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Volume Pump 3 (pump3Volume) data missing. Added column filled with NaN.']);
                end
                if sum(isnan(dataTable.pump3Volume)) == size(data,1) 
                    vD.pump3Volume = 'unset';
                end
                dataTable.Properties.VariableUnits{'pump3Volume'} = 'ml';
                dataTable.Properties.VariableDescriptions {'pump3Volume'} = 'Liquid present in the pump';

                %pump3PressureRel: relative pressure pump 3
                if ismember('pump_3_p', data.Properties.VariableNames)
                    dataTable.pump3PressureRel = data.pump_3_p;
                else
                    dataTable.pump3PressureRel = NaN(size(data,1),1);
                    warning([class(obj), ' - ', 'Pressure Pump 3 (pump3PressureRel) data missing. Added column filled with NaN.']);
                end  
                if sum(isnan(dataTable.pump3PressureRel)) == size(data,1) 
                    vD.pump3PressureRel = 'unset';
                end
                dataTable.Properties.VariableUnits{'pump3PressureRel'} = 'bar';
                dataTable.Properties.VariableDescriptions {'pump3PressureRel'} = 'Pressure measured internally in the pump (relative value)';
                
                %flowMass: flowMass of the water
                if ismember('weight', data.Properties.VariableNames)
                    dataTable.flowMass = data.weight;
                else
                    dataTable.flowMass = NaN(size(data,1),1);
                end
                
                if sum(isnan(dataTable.flowMass)) == size(data,1)
                    vD.flowMass = 'unset';
                    warning([class(obj), ' - ', 'Weight from scale (flowMass) data missing. Added column filled with NaN. Permeability calculation not possible!']);
                end
                dataTable.Properties.VariableUnits{'flowMass'} = 'kg';
                dataTable.Properties.VariableDescriptions {'flowMass'} = 'Weight of the water meassured on the scale';
                
            catch E
                error([class(obj), ' - ', 'The given dataset is missing a column or properties can not be added. Please control the given data to be complete.']);
            end
            
            %Recast time-String to datetime, calculate time dependend
            %variables like runtime and convert to timetable
            try
                %Set variable continuity for synchronizing data
                %time is unset, should not be filled
                %pressure and temperature are continious
                %deformation related meassurements are stepwise
                %volume in pumps is stepwise
                %flowMass on scale is stepwise
                dataTable.Properties.VariableContinuity = { vD.roomTemp ,vD.roomPressureAbs , ...
                    vD.fluidInTemp ,vD.fluidOutTemp ,vD.fluidPressureAbs ,vD.fluidPressureRel , ...
                    vD.hydrCylinderPressureAbs ,vD.hydrCylinderPressureRel ,vD.ConfiningPressureAbs ,vD.confiningPressureRel , ...
                    vD.strainSensor1Pos ,vD.strainSensor1Rel ,vD.strainSensor2Pos , ...
                    vD.strainSensor2Rel ,vD.pump1Volume ,vD.pump1PressureRel ,vD.pump2Volume ,vD.pump2PressureRel , ...
                    vD.pump3Volume ,vD.pump3PressureRel ,vD.flowMass};
                dataTable = retime(dataTable, 'secondly');
                
                %Calculate runtime
                rt = table(dataTable.datetime);
                dataTable.runtime = seconds(seconds(rt{:,1}-rt{1:1,1})); %working with datetime
                dataTable.Properties.VariableUnits{'runtime'} = 's';
                dataTable.Properties.VariableDescriptions{'runtime'} = 'Runtime in seconds since experiment start';
                
            catch E
                error([class(obj), ' - ', 'Can not add runtime to timetable and/or calculate time difference']);
            end
            
        end
        
        
        function dataTable = filterTableData(obj, data)
        %This function is used to filter most of the data
            
            %Prepare input for return, changed in data like filtering are
            %going to update the data in dataTable
            dataTable = data;
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %PRESSURE
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                dat = data.ConfiningPressureAbs;
                dat = fillmissing(dat, 'nearest');
                dat = lowpass(dat, 0.01);
                dataTable.ConfiningPressureAbs = round(dat, 2);
                
                dat = data.confiningPressureRel;
                dat = fillmissing(dat, 'nearest');
                dat = lowpass(dat, 0.01);
                dataTable.confiningPressureRel = round(dat, 2);

            catch
                warning([class(obj), ' - ', 'Error while filtering ConfiningPressureAbs/confiningPressureRel']);
            end
            
            try
                dat = data.roomPressureAbs;
                dat = fillmissing(dat, 'nearest');
                dat = movmedian(dat, 50);
                dataTable.roomPressureAbs = round(dat, 3);

            catch
                warning([class(obj), ' - ', 'Error while filtering roomPressureAbs']);
            end
            
            try
                dat = data.hydrCylinderPressureAbs;
                dat = fillmissing(dat, 'nearest');
                dat = lowpass(dat, 0.05);
                dataTable.hydrCylinderPressureAbs = round(dat, 1);
                
                dat = data.hydrCylinderPressureRel;
                dat = fillmissing(dat, 'nearest');
                dat = lowpass(dat, 0.05);
                dataTable.hydrCylinderPressureRel = round(dat, 1);

            catch
                warning([class(obj), ' - ', 'Error while filtering hydrCylinderPressureAbs/hydrCylinderPressureRel']);
            end
            
            try
                dat = data.fluidPressureAbs;
                dat = fillmissing(dat, 'nearest');
                dat =  movmedian(dat, 50);
                dataTable.fluidPressureAbs = round(dat, 3);
                
                dat = data.fluidPressureRel;
                dat = fillmissing(dat, 'nearest');
                dat = movmedian(dat, 50);
                dataTable.fluidPressureRel = round(dat, 3);

            catch
                warning([class(obj), ' - ', 'Error while filtering fluidPressureAbs/fluidPressureRel']);
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %TEMPERATURES
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %PT100 Temperatures as filtered by movmedian
            try
                dat = data.fluidInTemp;
                dat = filloutliers(dat, 'nearest', 'movmedian', 180);
                dat = fillmissing(dat, 'nearest');
                dat = movmedian(dat, 600);
                dataTable.fluidInTemp = round(dat, 1);

            catch
                warning([class(obj), ' - ', 'Error while filtering fluidInTemp']);
            end
            
            try
                dat = data.fluidOutTemp;
                dat = filloutliers(dat, 'nearest', 'movmedian', 180);
                dat = fillmissing(dat, 'nearest');
                dat = movmedian(dat, 600);
                dataTable.fluidOutTemp = round(dat, 1);

            catch
                warning([class(obj), ' - ', 'Error while filtering fluidOutTemp']);
            end
            
            try
                dat = data.roomTemp;
                dat = filloutliers(dat, 'nearest', 'movmedian', 180);
                dat = fillmissing(dat, 'nearest');
                dat = movmedian(dat, 600);
                dataTable.roomTemp = round(dat, 1);

            catch
                warning([class(obj), ' - ', 'Error while filtering roomTemp']);
            end
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %DEFORMATION
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Filtering of deformation must be used carefully, as we have a
            %changed deformation meassurement system
            %Check if a absulote deformation is given. Otherwise the
            %relative deformation will be saved as abs and the corected
            % (nulled) value will be saved as rel.
            try
                if (sum(isnan(dataTable.strainSensor1Pos)) == length(dataTable.strainSensor1Pos)) %Check if all absolute data is NaN
                    dat = movmedian(data.strainSensor1Rel, 30);
                    dataTable.strainSensor1Pos = round(dat, 3);
                    
                    dataTable.strainSensor1Rel = round(dat - min(dat), 3);
                else
                    dat = movmedian(data.strainSensor1Pos, 30);
                    dataTable.strainSensor1Pos = round(dat, 3);

                    dataTable.strainSensor1Rel = round(dat - min(dat), 3);
                end
                
            catch
                warning([class(obj), ' - ', 'Error while filtering strainSensor1Pos/strainSensor1Rel']);
            end
            
            try
                if (sum(isnan(dataTable.strainSensor2Pos)) == length(dataTable.strainSensor2Pos)) %Check if all absolute data is NaN
                    dat = movmedian(data.strainSensor2Rel, 30);
                    dataTable.strainSensor2Pos = round(dat, 3);
                    
                    dataTable.strainSensor2Rel = round(dat - min(dat), 3);
                else
                    dat = movmedian(data.strainSensor2Pos, 30);
                    dataTable.strainSensor2Pos = round(dat, 3);

                    dataTable.strainSensor2Rel = round(dat - min(dat), 3);
                end
            catch
                warning([class(obj), ' - ', 'Error while filtering strainSensor2Pos/strainSensor2Rel']);
            end
            
        end
        
        function dataTable = createTable(obj)
            dataTable = obj.filteredData(:,{'runtime'}); 
        end
        
    end
    
    methods
        function obj = ExperimentsData(experimentNo, data)
            %Input parameters are the experiment number and a table
            %containing all experiments data. The handed over data is a
            %class of table, will be converted into a timetable and saved
            %in this object.
            
            %Inputdata consistence checks
                %Check if there are two variables handed over
                if (nargin ~= 2)
                    error('Not enough input arguments. Two input parameters have to be handed over: experimentNo as Integer and data as timetable.')
                end

                %Check if the variable experimentNo is numeric
                if ~isnumeric(experimentNo)
                    error(['Input "experimentNo" must consider a numeric-variable. Handed variable is class of: ',class(experimentNo)])
                end

                %Check if the variable data is a table
                if ~istimetable(data)
                    error(['Input "data" must consider a timetable-variable. Handed variable is class of: ',class(data)])
                end

                %Check if the data table is empty
                if height(data) == 0
                    error('Data table for the experiment is empty')
                end
            
            %Saving original data in object
            obj.originalData = data;
                
            %Organize all data in the table: adding units and desciptions
            %Convert from table to timetable
            data = obj.organizeTableData(data);
            
            %Filter all data
            obj.filteredData = obj.filterTableData(data);
            
            %Saving variables in actual object
            obj.experimentNo = experimentNo; 
            obj.rows = height(data);
            
        end
        
        function fig = showDebugPlotSingle(obj, columnName)
        %Function to plot a single rows data as original and filtered data
        %When columnName parameter is 'all' then all filtered columns will
        %be shown in a seperate figure. Otherwise the given columnName will
        %be shown.
            try
                if (columnName == "all")

                    fig = [];
                    variables=obj.originalData.Properties.VariableNames;

                    for k=1:length(variables)

                        x1 = obj.originalData.runtime;
                        x2 = x1;

                        y1 = obj.originalData.(k);
                        y2 = obj.filteredData.(k);

                        y1 = fillmissing(y1, 'nearest');
                        y2 = fillmissing(y2, 'nearest');

                        if (not(isequal(y1, y2)) && not(sum(isnan(y1)) == length(y1)))

                            figTemp = figure;
                            plot(x1,y1,':' ,x2,y2);
                            title(variables(k), 'Interpreter', 'none');
                            legend('Original', 'Filtered');

                            fig = [fig, figTemp];
                        end
                    end

                else

                    x1 = obj.originalData.runtime;
                    x2 = x1;

                    y1 = obj.originalData.(columnName);
                    y2 = obj.filteredData.(columnName);

                    fig = figure;
                    plot(x1,y1,x2,y2);
                    title(columnName, 'Interpreter', 'none');
                    legend('Original', 'Filtered');

                end
                
            catch E
                throw(E);
            end
            
        end
        
        function plot = showDebugPlot(obj)
        %Function to plot all data in dataTable within a stacked plot, to
        %get a short overview over all existing data
            plot = stackedplot(obj.originalData,'-x');
        end
    end
    
    methods (Static)
        function density = waterDensity(temp)
        %Function to calculate the density of water at a specific temperature.
        %Input parameters:
        %   temp : temperature in �C
        %Returns a double containing the water density.
        %
        %Water density is herefore approximated by a parabolic function:
        %999.972-7E-3(T-4)^2
        
            if (nargin ~= 1)
                error('Not enough input arguments. One input parameter needed in �C as numeric or float.')
            end

            %Check if the variable experimentNo is numeric
            if ~isnumeric(temp)
                error(['Input parameter temperature needed in �C as numeric or float. Handed variable is class of: ',class(temp)])
            end
            
            density = 999.972-(temp-4).^2*0.007;
            
        end
    end

%% GETTER
    methods

        function rows = get.rows(obj)
            rows = obj.rows;
        end
        
        
        function experimentNo = get.experimentNo(obj)
            experimentNo = obj.experimentNo;
        end
        
        function data = getFilteredDataTable(obj)
            warning('This kind of access is possible but not recommended. Please use getter methods/functions to access data in this table!');
            data = obj.filteredData; %make timetable
        end
        
        function data = getOriginalDataTable(obj)
            warning('This kind of access is possible but not recommended. Please use getter methods/functions to access data in this table!');
            data = obj.originalData; %make timetable
        end
        
        
        function dataTable = getRoomTemperature(obj)
        %Returns a timetable with the following columns: runtime, timestamp, timeDiff, roomTemp
            dataTable = obj.createTable();
            dataTable = [dataTable obj.filteredData(:,{'roomTemp'})];
        end
        
        
        function dataTable = getAllTemperatures(obj)
        %Returns a timetable containing all temperature data. Missing
        %temperature datasets will be filled by linear interpolation
        %between the next neighboor.
            colNames = ''; %Variable for output-message containing column Names
            dataTable = obj.createTable;
            
            %Searching for all variables containing temperature data (�C)
            for i=1:width(obj.filteredData)
                if (strcmp(char(obj.filteredData(:,i).Properties.VariableUnits),'�C'))
                    colNames = strcat(colNames, obj.filteredData(:,i).Properties.VariableNames,{'; '});
                    dataTable = [dataTable obj.filteredData(:,i)];
                end
                
            end
            
            disp(strcat(class(obj), {' - '},  {'Found the following temperature related columns: '}, colNames));
        end
        
        
        function dataTable = getAllPressureRelative(obj)
        %Returns a timetable containing all relative pressure data: time, runtime
        %fluidPressureRel, hydrCylinderPressureRel, confiningPressureRel
            dataTable = obj.createTable();
            dataTable = [dataTable obj.filteredData(:,{'fluidPressureRel', 'hydrCylinderPressureRel', 'confiningPressureRel'})];
        end
        
        
        function dataTable = getAllPressureAbsolute(obj)
        %Returns a timetable containing all absolute pressure data: time, runtime
        %fluidPressureAbs, hydrCylinderPressureAbs, ConfiningPressureAbs
            dataTable = obj.createTable();
            dataTable = [dataTable obj.filteredData(:,{'roomPressureAbs', 'fluidPressureAbs', 'hydrCylinderPressureAbs', 'ConfiningPressureAbs'})];
        end
        
        
        function dataTable = getDeformationRelative(obj)
        %Returns a timetable containing deformation data of the specimen: time, runtime
        %strainSensor1Rel, strainSensor2Rel, strainSensorMean
            dataTable = [obj.createTable() obj.filteredData(:,{'strainSensor1Rel','strainSensor2Rel',})];    

            %Calculating the mean deformation influenced by deformatoin
            %sensor 1 and 2. NaN entrys will be ignored.
            dataTable.strainSensorsMean = mean([dataTable.strainSensor1Rel, dataTable.strainSensor2Rel], 2, 'omitnan');
            dataTable.Properties.VariableUnits{'strainSensorsMean'} = 'mm';
            dataTable.Properties.VariableDescriptions {'strainSensorsMean'} = 'Mean relative deformation from sensor 1 and 2, zeroed at the beginning of the experiment';
        end
        
        
        function dataTable = getConfiningPressure(obj)
        %Returns a timetable containing confing pressure data: time, runtime, confiningPressureRel
            dataTable = obj.createTable();  
            dataTable.confiningPressureRel = obj.getAllPressureRelative.confiningPressureRel;
            dataTable.Properties.VariableUnits{'confiningPressureRel'} = obj.getAllPressureRelative.Properties.VariableUnits{'confiningPressureRel'};
            dataTable.Properties.VariableDescriptions{'confiningPressureRel'} = obj.getAllPressureRelative.Properties.VariableDescriptions{'confiningPressureRel'};
        end
        
        
        function dataTable = getconfiningPressureRelative(obj)
        %DEPRECATED!!
        %Returns a timetable containing confing pressure data: time, runtime, confiningPressureRel
            warning('Function getconfiningPressureRelative() deprecated. Use getConfiningPressure()')
        
            dataTable = obj.getConfiningPressure();
        end
        
        function dataTable = getBassinPumpData(obj)
        %Returns a timetable containing confing pressure data: time, runtime
        %pump1PressureRel, pump2PressureRel, pump3PressureRel, pumpPressureMean, pump1Volume, pump2Volume, pump3Volume, pumpVolumeSum
        %
        %IMPORTANT:
        %The mean pump pressure has to be used with caution. When the
        %volume of a pump is empty, and it has to be refilled, there will
        %be a pressure loss!
            dataTable = [obj.createTable() obj.filteredData(:,{'pump1PressureRel','pump1Volume','pump2PressureRel','pump2Volume','pump3PressureRel','pump3Volume'})];
            
            %Calculating the mean pump pressure and volume influenced by
            %all three pumps. Ignoring NaN entrys.
            dataTable.pumpPressureMean = mean([dataTable.pump1PressureRel, dataTable.pump2PressureRel, dataTable.pump3PressureRel],2,'omitnan');
            dataTable.Properties.VariableUnits{'pumpPressureMean'} = dataTable.Properties.VariableUnits{'pump1PressureRel'};
            dataTable.Properties.VariableDescriptions{'pumpPressureMean'} = 'Mean pressure measured internally in all pumps (relative value)';
            
            dataTable.pumpVolumeSum = sum([dataTable.pump1Volume, dataTable.pump2Volume, dataTable.pump3Volume],2,'omitnan');
            dataTable.Properties.VariableUnits{'pumpVolumeSum'} = dataTable.Properties.VariableUnits{'pump1Volume'};
            dataTable.Properties.VariableDescriptions{'pumpVolumeSum'} = 'Sum of present liquid in all pumps.';
        end
        
        
        
        function dataTable = getFlowData(obj)
        %Returns a timetable containing all flow data relevant data: time, runtime
        %flowMass, fluidPressureRel, fluidOutTemp,
            dataTable = [obj.createTable() obj.filteredData(:,{'flowMass'})];
            
            tempData = obj.getAllTemperatures;
            dataTable.fluidOutTemp = tempData.fluidOutTemp;
            dataTable.Properties.VariableUnits{'fluidOutTemp'} = tempData.Properties.VariableUnits{'fluidOutTemp'};
            dataTable.Properties.VariableDescriptions{'fluidOutTemp'} = tempData.Properties.VariableDescriptions{'fluidOutTemp'};
            
            tempData= obj.getAllPressureRelative;
            dataTable.fluidPressureRel = tempData.fluidPressureRel;
            dataTable.Properties.VariableUnits{'fluidPressureRel'} = tempData.Properties.VariableUnits{'fluidPressureRel'};
            dataTable.Properties.VariableDescriptions{'fluidPressureRel'} = tempData.Properties.VariableDescriptions{'fluidPressureRel'};
        end
        
        function dataTable=getCalculationTable(obj)
        %DEPRECATED!!
        %Helperfunction to collect all relevant data for permeability
        %calculation. Calculates the density
        %Returns a timetable containing all flow data relevant data: time, runtime
        %flowMass, fluidPressureRel, fluidOutTemp, strainSensorsMean and density
            warning('Function getCalculationTable is deprecated. Load the data directly without helper function!');
            
            dataTable = obj.getFlowData;
            
            tempData = obj.getDeformationRelative();
            dataTable.strainSensorsMean = tempData.strainSensorsMean;
            dataTable.Properties.VariableUnits{'strainSensorsMean'} = tempData.Properties.VariableUnits{'strainSensorsMean'};
            dataTable.Properties.VariableDescriptions{'strainSensorsMean'} = tempData.Properties.VariableDescriptions{'strainSensorsMean'};
            
            dataTable.density = obj.waterDensity(dataTable.fluidOutTemp);
            dataTable.Properties.VariableUnits{'density'} = 'kg/m�';
            dataTable.Properties.VariableDescriptions{'density'} = 'Watedensity depening on the fluid temperature on the flowMass (fluidOutTemp)';
        end 

        
        function permeability = getPermeability(obj, length, diameter, timestep, debug)                   
            %Input parameters:
            %   length : height of specimen in cm
            %   diameter: diameter of specimen in cm
            %   timestep: timestep between to calculation point of perm
            %   debug: all influencing parameters for permeability calculation
            %This function calculates the permeability and returns a
            %timetable containing the permeability and runtime. 
            %FluidPressureRel and flowMassDiff outliers are detected using the mean method. Alpha is included.
            
            %Check for correct input parameters
            if nargin == 3
                warning('Set timestep to default: 5 minutes');
                timestep = 5;
                debug = false;
            end
            
            if nargin == 4
                debug = false;
            end
            
            if nargin == 5
                warning('Debug mode in getPermeability: all parameters as output');
            end
            
            if nargin < 3
                error('Not enough input arguments. specimen length; specimen diameter; timestep (optional)');
            end
            
            if ~isnumeric(length) || ~isnumeric(diameter) || ~isnumeric(timestep) || diameter <= 0 || length <= 0 || timestep <= 0 || isnan(diameter) || isnan(length)
                error('Input parameters length, diameter and timestep have to be numeric and bigger zero!');
            end
            
            try
                %Catch all relevant data as timetable
                dataTable = obj.getFlowData;
                dataTable.strainSensorsMean = obj.getDeformationRelative.strainSensorsMean;
                if isnan(dataTable.fluidOutTemp)
                    dataTable.fluidOutTemp = zeros(size(dataTable,1),1)+18;
                    disp([class(obj), ' - ', 'Fluid outflow temperature set to 18�C.']);
                end
                dataTable.density = obj.waterDensity(dataTable.fluidOutTemp);
                
                %Set length from cm to m
                length = length / 100;

                %Retime the dataTable to given timestep
                start = dataTable.datetime(1);
                time = (start:minutes(timestep):dataTable.datetime(end));
                dataTable = retime(dataTable,time,'linear');

                %Calculating differences
                dataTable.flowMassDiff = [0;max(0, diff(dataTable.flowMass))]; %Calculate flowMass difference between to entrys, no negative values are allows: max(0,value)
                dataTable.timeDiff = [0;diff(dataTable.runtime)]; %Calculate time difference between to entrys

                %Add deltaL (variable) and A (constant)
                dataTable.deltaL = length - (dataTable.strainSensorsMean./1000);
                A = ((diameter/100)/2)^2*pi; %crosssection

                %Checking data for outliers
                %dataTable.fluidPressureRel = filloutliers(dataTable.fluidPressureRel,
                %'linear', 'mean'); % no longer needes. Is done in creator
                dataTable.flowMassDiff = filloutliers(dataTable.flowMassDiff, 'linear', 'movmean', [0 240]);
                %dataTable.flowMassDiff = round(dataTable.flowMassDiff,6); %round to avoid spikes

                %Handling emptying the scale for the flow measurement
                    %Split table if flowMass drops and flowMass difference between
                    %to entrys in the given timestep is below zero
                    flowMassDropPoints = find(dataTable.flowMassDiff<-0.01); %find where flowMass difference drops to below zero and count
                    TF = isempty(flowMassDropPoints);

                    flowMassDropPoints=[1; flowMassDropPoints]; %add starting index 1

                    %Splitting up
                    if TF==0
                        %split datatable where flowMass drops below zero
                        dataTableSplitted = cell(numel(flowMassDropPoints)-1, 1); %create cell array in which to store the split tables

                        for k=2:numel(flowMassDropPoints)
                            dataTableSplitted{k-1} = dataTable(flowMassDropPoints(k-1):flowMassDropPoints(k)-1,:);
                        end

                        dataTableSplitted{k,1} = dataTable(flowMassDropPoints(end):end,:); %add end section of table

                    else
                        %create single cell array if flowMass does not drop below zero
                        dataTableSplitted = cell(1,1);
                        dataTableSplitted{1,1} = dataTable;

                    end

                    %Calculating the permeability for each of the splitted data
                    %tables
                    for j = 1:numel(dataTableSplitted)
                        tempTable = dataTableSplitted{j,1}; %Save data in temporarily table

                        g = 9.81; %Gravity m/s� or N/kg

                        tempTable.h = (tempTable.fluidPressureRel .* 100000) ./ (tempTable.density .* g); %Pressure difference h between inflow and outflow in m
                        tempTable.WaterFlowVolume = (tempTable.flowMassDiff ./ tempTable.density); %water flow volume Q in m�

                        tempTable.k = ((tempTable.WaterFlowVolume ./ seconds(tempTable.timeDiff)) .* tempTable.deltaL) ./ (tempTable.h .* A); %calculate permeability

                        %Normalize permeability to a reference temperature of 10 �C
                        tempTable.Itest = (0.02414 * 10.^((ones(size(tempTable.k)) * 247.8) ./ (tempTable.fluidOutTemp + 133)));
                        tempTable.IT = (0.02414 * 10.^((ones(size(tempTable.k)) * 247.8) ./ (10 + 133)));%Using reference temperature of 10 �C
                        tempTable.alpha = tempTable.Itest ./ tempTable.IT;
                        tempTable.kT = tempTable.k .* tempTable.alpha;

                        dataTableSplitted{j,1} = tempTable; %Save temp data in original table
                    end

                %Assembly the dataTableSplitted back into one dataTable
                dataTable = cat(1,dataTableSplitted{:});

                %Create output timetable-variable
                if debug
                    permeability = dataTable;
                else
                    permeability = dataTable(:,{'runtime', 'flowMassDiff'});
                    permeability.Properties.VariableUnits{'flowMassDiff'} = 'kg';
                    permeability.Properties.VariableDescriptions{'flowMassDiff'} = 'Difference of flow mass between two calculation steps';
                end
                permeability.permeability = dataTable.kT;
                permeability.Properties.VariableUnits{'permeability'} = 'm/s';
                permeability.Properties.VariableDescriptions{'permeability'} = 'Coefficient of permeability alpha corrected to 10�C';
            
                permeability.alphaValue = dataTable.alpha;
                permeability.Properties.VariableUnits{'alphaValue'} = '-';
                permeability.Properties.VariableDescriptions{'alphaValue'} = 'Rebalancing factor to compare permeabilitys depending on the fluid temperature';
            catch
                warning([class(obj), ' - ', 'Calculating permeability FAILED!']);
                
                permeability = dataTable(:,{'runtime'});
                permeability.flowMassDiff = zeros(size(dataTable,1),1);
                permeability.permeability = zeros(size(dataTable,1),1);
                permeability.alphaValue = zeros(size(dataTable,1),1);
            end
                          
        end 
        
        function dataTable = getAnalytics(obj)
        %DEPRECATED!!
            warning('Function getCalculationTable is deprecated. Use getAnalyticsDataForGUI() instead!');
            dataTable = obj.getAnalyticsDataForGUI();
        end
        
        function dataTable = getAnalyticsDataForGUI(obj)
            %This function returns a table with all relevant data for
            %the GUI. This includes the flowMass, flowMass difference,
            %fluid pressure, hydraulic cylinder pressure, confining
            %pressure, bassin pump data, room temperature, fluid
            %temperature, deformation mean
            %All data will be synchronized and linear interpolated via
            %retime-function of the timetable.

            %get table and add neccessary variables    
            dataTable = obj.getFlowData;
            dataTable.strainSensorsMean = obj.getDeformationRelative.strainSensorsMean;
            dataTable.strainSensor1MeanDelta = obj.getDeformationRelative.strainSensor1Rel - dataTable.strainSensorsMean;
            dataTable.strainSensor2MeanDelta = obj.getDeformationRelative.strainSensor2Rel - dataTable.strainSensorsMean;
            dataTable.hydrCylinderPressureRel = obj.getAllPressureRelative.hydrCylinderPressureRel;
            dataTable.confiningPressureRel = obj.getAllPressureRelative.confiningPressureRel;
            dataTable.pumpVolumeSum = obj.getBassinPumpData.pumpVolumeSum;
            
            dataTable.roomTemp = fillmissing(obj.getAllTemperatures.roomTemp, 'linear');
            dataTable.fluidOutTemp = fillmissing(dataTable.fluidOutTemp, 'linear');
            dataTable.flowMass = fillmissing(dataTable.flowMass, 'previous');
            
            dataTable.density = obj.waterDensity(dataTable.fluidOutTemp);
            %%%%%%%%%%%
            dataTable.flowMassDiff = [0; diff(dataTable.flowMass)]; %Is this correct???
            
            
            %It is possible to synchronize two timetables even if the data
            %is not consistent. The datatasets will be interpolized linear.
            %https://de.mathworks.com/help/matlab/matlab_prog/combine-timetables-and-synchronize-their-data.html
            %dataTable = synchronize(dataTable,permeability,);
                
        end 

    end
end 
 
