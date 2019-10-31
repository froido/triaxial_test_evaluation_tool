classdef TriaxTestHandler < handle
    %
    %
    %
    % 2019-10-23 Biebricher
    %   * New class
    
    properties %(GetAccess = private, SetAccess = private)
		listExperimentNo;
        experiment = struct('metaData', [], 'specimenData', [], 'testData', [], 'calculatedData', []); %Struct handling all experiments
        dbConnection; %Database connection
    end
    
    %%
    
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
		
		function result = isinteger(value)
		%Check wether the input value is an integer or nor
		%Input parameters:
        %   value : any value
        %Returns true if value is an integer.
		
			try
				%Experiment number is an numeric-value?
				if ~isnumeric(value)
					result = false;

				%Experiment number is an integer-value?
				elseif ~mod(value,1) == 0
					result = false;

				else
					result = true;
				end
				
			catch E
				warning([class(obj), ' - ', E.message]);
				result = false;
			end
			
			
		end
    end
    
    %%
    
    methods (Access = private)
        function result = validateExperimentNoInput(obj, experimentNo)
        %Check if the variable experimentNo is an integer and if the
        %experiment number exists and is loaded allready.
        
            %Experiment number is an numeric-value?
			if ~obj.isinteger(experimentNo)
                result = ['Input "experimentNo" must consider a integer-variable. Handed variable is class of: ',class(experimentNo)];
				return
			end

			%Experiment exists in database?
			if ~sum(ismember(obj.listExperimentNo, experimentNo))
				result = ['Experiment number ', int2str(experimentNo), ' does not exist within the database.'];
				return
			end
            
            %Result true, if the test passes successfully
            result = true;
            
		end

		
        function result = isExperimentLoaded(obj, experimentNo)
        %Function checks, if the input experiment number is allready loaded
        %into this class.
        %
        %Input parameters:
        %   experimentNo : number of the experiment
        %Returns true if dataset is loaded
        
            try
                %Method to check if a particular experiment is allready loaded
                %into the experiment struct.
                if isa(obj.experiment(experimentNo).metaData, 'ExperimentsMetaData') && ...
                    isa(obj.experiment(experimentNo).specimenData, 'ExperimentsSpecimenData') && ...
                    isa(obj.experiment(experimentNo).testData, 'ExperimentsData')

                    result = true;
                else
                    result = false;
                end
            catch
                disp([class(obj), ' - ', 'Experiment number ', int2str(experimentNo), ' has not been loaded yet.']);
                result = false;
            end
            
        end
        
        
        function result = calcFlowMassData (obj, experimentNo, timestep)
        %This function processes the incoming flow measurement data 
        %(flowMass). It calculates the weight difference between two time 
        %steps (flowMassDiff), the flow rate per time unit (flowRate), and 
        %the accumulated weight (flowMassAcc) based on the corrected differences.
        %A discontinuous system (scale with container or graduated pipette) 
        %is used to measure the flow rate, which must be emptied several 
        %times during the test period. The emptying causes jumps in the 
        %course of the measurement, which have to be calculated out. The 
        %elimination of the jumps is guaranteed by an outlier detection which 
        %checks whether there are deviations from a 'percentile' [3%<x>97%] in 
        %the measurement data. Since the flow rate remains relatively constant 
        %over time and is not subject to major fluctuations, viewing a quartile 
        %as an outlier provides perfect results.
        %For verification purposes, the measured flow (flowMass) can be 
        %compared with the accumulated flow (flowMassAcc). The course of 
        %the two curves must not differ significantly. The same applies to 
        %the difference per time step before and after smoothing.
        %
        %Input parameters:
        %   experimentNo : number of the experiment
        %Returns true to success
        
            disp([class(obj), ' - ', 'Calculating accumulated flow mass, flow mass difference per timestep and flow rate for experiment number ', int2str(experimentNo), ' (timestep = ', int2str(timestep), ').']);

            dataTable = obj.experiment(experimentNo).testData.getFlowData;
			
			%Retime if a particular timestep is given
			if ~timestep == 0
				start = dataTable.datetime(1);
				time = (start:minutes(timestep):dataTable.datetime(end));
				dataTable = retime(dataTable, time, 'linear');
			end
			
            %Calculating differences
            dataTable.flowMassDiffOrig = [0; diff(dataTable.flowMass)]; %Calculate flowMass difference between to entrys
            dataTable.timeDiff = [0;diff(dataTable.runtime)]; %Calculate time difference between to entrys

            %Identify the outliers
			%Size of the percentiles depends on the length of the experiment. Following numbers are empirically determinded.
			%
			durationHours = hours(obj.experiment(experimentNo).metaData.timeEnd - obj.experiment(experimentNo).metaData.timeStart);
			if durationHours > 150
				percentiles = [1 99];
			else
				percentiles = [5 95];
			end
			
            dataTable.flowMassDiff = filloutliers(dataTable.flowMassDiffOrig, 'linear', 'percentile', percentiles);
            dataTable.flowMassDiff = fillmissing(dataTable.flowMassDiff, 'constant', 0);
            
            %Calculate comulated sum of mass differences
            dataTable.flowMassAcc = cumsum(dataTable.flowMassDiff, 'omitnan');

            %Calculate flow rate
            dataTable.flowRate = dataTable.flowMassDiff ./ obj.waterDensity(dataTable.fluidOutTemp) ./ seconds(dataTable.timeDiff);

            %Create output timetable-variable
            dataTable.Properties.VariableUnits{'flowMassDiffOrig'} = 'kg';
            dataTable.Properties.VariableDescriptions{'flowMassDiff'} = 'Difference of flow mass between two calculation steps (without outlier detection)';
            dataTable.Properties.VariableUnits{'flowMassDiff'} = 'kg';
            dataTable.Properties.VariableDescriptions{'flowMassDiff'} = 'Difference of flow mass between two calculation steps (with outlier detection)';
            dataTable.Properties.VariableUnits{'flowMassAcc'} = 'kg';
            dataTable.Properties.VariableDescriptions{'flowMassAcc'} = 'Accumulated fluid flow mass';
            dataTable.Properties.VariableUnits{'flowRate'} = 'm�/s';
            dataTable.Properties.VariableDescriptions{'flowMassAcc'} = 'Flow rate through the sample';
			
			%Save dataTable in object
            obj.experiment(experimentNo).calculatedData.flowMass.data = dataTable;
			obj.experiment(experimentNo).calculatedData.flowMass.timestep = timestep;
            
%            plot(dataTable.runtime, dataTable.flowMassDiff, dataTable.runtime, dataTable.flowMassDiffOrig, ':')
%            plot(dataTable.runtime, dataTable.flowMass(1)+dataTable.flowMassAcc, dataTable.runtime, dataTable.flowMass(1)+cumsum(dataTable.flowMassDiffOrig), '--', dataTable.runtime, dataTable.flowMass, ':')

            result = true;
        end
        
    end
    
    %%
    
    methods
        function obj = TriaxTestHandler()
            import MeridDB.*
            
            dbUser = 'hiwi_ro';
            dbPassword = '#meridDB2019';
            serverIpAdress = '134.130.87.47';
            serverPort = 3306;
            
            %Initialize database
            obj.dbConnection = MeridDB(dbUser, dbPassword, serverIpAdress, serverPort);
			
			%Load list of all experiments
			obj.listExperimentNo = single(obj.getExperimentOverview.experimentNo);
        end
        
        function result = getExperimentOverview(obj)
        %Method loading all listed experiments from the database and
        %returning a list of all experiments including number, duration
        %and name
            result = obj.dbConnection.getExperiments;
        end
        
        function result = experimentExists(obj, experimentNo)
        %Method checking if an experiment with the given experiment
        %number exists.
        %
        %Input parameters:
        %   experimentNo : number of the experiment
        %Returns true if experiment exists
            
            result = obj.dbConnection.experimentExists(experimentNo);
        end
        
        
        
        function result = getLoadedExperiments(obj)
        %Returns a list of all loaded experiments
            
            result = [];
            
            for experimentNo = 1:numel(obj.experiment)
                if obj.isExperimentLoaded(experimentNo)
                    result = [result, experimentNo];
                end
            end 
        end
        
        
        function result = loadExperiment(obj, experimentNo)
        %Method to load a given experiment into the experiment struct.
        %
        %Input parameters:
        %   experimentNo : number of the experiment
        %Returns true if dataset is loaded
			
            %Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
            if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
            end
		
            try
                %Load meta data
                obj.experiment(experimentNo).metaData = obj.dbConnection.getMetaData(experimentNo);
                %Load specimen data
                specimenId = obj.experiment(experimentNo).metaData.specimenId;
                obj.experiment(experimentNo).specimenData = obj.dbConnection.getSpecimenData(experimentNo, specimenId);
                
                %Load test data
				%Limit test data to testing time from metadata
				formatOut = 'yyyy/mm/dd HH:MM:SS';
				timeStart = datestr(obj.experiment(experimentNo).metaData.timeStart, formatOut);
				timeEnd = datestr(obj.experiment(experimentNo).metaData.timeEnd, formatOut);
                obj.experiment(experimentNo).testData = obj.dbConnection.getExperimentData(experimentNo, timeStart, timeEnd); %, obj.experiment(experimentNo).metaData.timeStart, obj.experiment(experimentNo).metaData.timeEnd);
                
                %Set output variable to true if no error occured
                result = true;
            catch E
                warning([class(obj), ' - ', E.message]);
                warning([class(obj), ' - ', 'Experiment number ', int2str(experimentNo), ' cannot be loaded. An error accured while catching the dataset from database.']);
                
                result = false;
            end 
		end
        
		function result = getGraphData(obj, experimentNo, timestep, label)
			
			%Check if the variable experimentNo is valid
			validateExpNo = obj.validateExperimentNoInput(experimentNo);
			if ischar(validateExpNo)
				error([class(obj), ' - ', validateExpNo]);
			end
			
			if ~obj.isinteger(timestep)
				error([class(obj), ' - ', 'Input value timestep has to be a positive integer value.']);
			elseif timestep < 0
				error([class(obj), ' - ', 'Input value timestep has to be a positive integer value.']);
			end
			
			%Select case to determine which values are used and where to find the needed dataset
			switch label
				
				case 'runtime'  
					dataLabel = 'runtime';
					dataTable = obj.getFlowMassData(experimentNo);
					result.data = dataTable(:,{dataLabel});
					result.label = 'Runtime';
					result.unit = 'hh:mm';
					
				case 'permeability'
					dataLabel = 'permeability';
					dataTable = obj.getPermeability(experimentNo, timestep);
					result.data = dataTable(:,{dataLabel});
					result.label = 'Permeability';
					result.unit = dataTable.Properties.VariableUnits(dataLabel);
                
				case 'strainSensorMean'
					dataLabel = 'strainSensorMean';
					dataTable = obj.getStrain(experimentNo);
					result.data = dataTable(:,{dataLabel});
					result.label = 'Probe Deformation';
					result.unit = dataTable.Properties.VariableUnits(dataLabel);
					
				otherwise
						warning([class(obj), ' - ', 'unknown columns']);
                        result = [];
			end
			
			
		end
		
        function result = getFlowMassData(obj, experimentNo, timestep, reCalc)
        %Returns a table containing all flow mass datasets
        %
        %Input parameters:
        %   experimentNo : number of the experiment
        %   reCalc: trigger to recalculate the flow mass dataset
        %Returns true if dataset is loaded
        
            %Inputdata consistence checks
            %Check if there are two variables handed over
			if nargin == 2
				timestep = 0;
                reCalc = false;
			end
			
			if nargin == 3
                reCalc = false;
			end
            
            if (nargin < 2)
                error([class(obj), ' - ', 'Not enough input arguments. One input parameter have to be handed over: experimentNo (reCalc optional)']);
            end

            %Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
            if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
            end

            %Check if the variable recalc is true/false
            if ~islogical(reCalc)
                error(['Input "reCalc" must consider a logical-value. Handed variable is class of: ',class(reCalc)])
			end
			
			%Check if the variable recalc is true/false
            if ~obj.isinteger(timestep)
				error(['Input "timestep" must consider a positive integer-value. Handed variable is class of: ',class(reCalc)]);
			elseif timestep < 0
				error(['Input "timestep" must consider a positive integer-value. Handed variable is class of: ',class(reCalc)]);
            end
        
            %Check if experiment is allready loaded
            if ~obj.isExperimentLoaded(experimentNo)
                warning([class(obj), ' - ', 'Experiment number ', int2str(experimentNo), ' has not been loaded yet.']);
                result = [];
                return;
            end

            %Check if flowmass for given experiment has allready been
            %calculated
            if ~isfield(obj.experiment(experimentNo).calculatedData, 'flowMass') || reCalc
                %Calculate flow mass stuff
				disp([class(obj), ' - ', 'FlowMass recalculation necessary: no data available or recalculation forced']);
                obj.calcFlowMassData(experimentNo, timestep);
				
			%Check if the timestep corresponds to the given timestep
			elseif obj.experiment(experimentNo).calculatedData.flowMass.timestep ~= timestep
				%Calculate flow mass stuff
				disp([class(obj), ' - ', 'FlowMass recalculation necessary: timestep (', int2str(obj.experiment(experimentNo).calculatedData.flowMass.timestep), ') does not match (', int2str(timestep), ')']);
                obj.calcFlowMassData(experimentNo, timestep);
            end
            
            result = obj.experiment(experimentNo).calculatedData.flowMass.data;
        
        end
        
        function result = getRockDataTableContent(obj, experimentNo)
        %Preparing rock and specimen specific data to be printed into a
        %table in the gui. Names, values and units will be shown.
        %Input parameters:
        %   experimentNo : number of the experiment
        %Returns a table containing all specimen and rock data
            
            %Inputdata consistence checks            
            if (nargin ~= 2)
                error([class(obj), ' - ', 'Not enough input arguments. One input parameter have to be handed over: experimentNo']);
            end

            %Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
            if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
            end
        
            %Check whether the experiment has already been loaded.
            if ~obj.isExperimentLoaded(experimentNo)
                warning([class(obj), ' - ', 'Experiment number ', int2str(experimentNo), ' has not been loaded yet.']);
                result = [];
                return;
            end
            
            %Loading rock data table
            specimenData = obj.experiment(experimentNo).specimenData;
            
            dataTable = table();
            
            %Creating the output table [name, value + unit]            
            dataTable = [dataTable; {'Experiment Number', num2str(specimenData.experimentNo)}];
            dataTable = [dataTable; {'Specimen Name', specimenData.specimen}];
            
            dataTable = [dataTable; {'Rock Name', specimenData.rockType}];
            dataTable = [dataTable; {'Rock Description', specimenData.rockDescription}];
            
            dataTable = [dataTable; {'Height', [num2str(specimenData.height.value, 4), ' ' , specimenData.height.unit]}];
            dataTable = [dataTable; {'Diameter', [num2str(specimenData.diameter.value, 4), ' ' , specimenData.diameter.unit]}];
            
            dataTable = [dataTable; {'Mass Saturated', [num2str((specimenData.massSaturated.value/1000), 4), ' ' , 'kg']}];
            dataTable = [dataTable; {'Mass Wet', [num2str((specimenData.massWet.value/1000), 4), ' ' , 'kg']}];
            dataTable = [dataTable; {'Mass Dry', [num2str((specimenData.massDry.value/1000), 4), ' ' , 'kg']}];
            
            dataTable = [dataTable; {'Density Wet', [num2str(specimenData.rockDensityWet.value, 3), ' ' , specimenData.rockDensityWet.unit]}];
            dataTable = [dataTable; {'Density Saturated', [num2str(specimenData.rockDensitySaturated.value, 3), ' ' , specimenData.rockDensitySaturated.unit]}];
            dataTable = [dataTable; {'Density Dry', [num2str(specimenData.rockDensityDry.value, 3), ' ' , specimenData.rockDensityDry.unit]}];
            dataTable = [dataTable; {'Density Grain', [num2str(specimenData.rockDensityGrain.value, 3), ' ' , specimenData.rockDensityGrain.unit]}];
            
            dataTable = [dataTable; {'Permeability Coefficient', [num2str(specimenData.permeabilityCoefficient.value, 2), ' ' , specimenData.permeabilityCoefficient.unit]}];
            dataTable = [dataTable; {'Porosity', [num2str(specimenData.porosity.value, 3), ' ' , specimenData.porosity.unit]}];
            dataTable = [dataTable; {'Void Ratio', [num2str(specimenData.voidRatio.value, 3), ' ' , specimenData.voidRatio.unit]}];
            
            dataTable = [dataTable; {'Uniaxial Compression Strength', [num2str(specimenData.uniAxialCompressiveStrength.value), ' ' , specimenData.uniAxialCompressiveStrength.unit]}];
            dataTable = [dataTable; {'Uniaxial E-Modulus', [num2str(specimenData.uniAxialEModulus.value), ' ' , specimenData.uniAxialEModulus.unit]}];
            
            result = dataTable;
        end
            
        function result = clearExperimentCache(obj)
        %Deleting all loaded experiments from the cache.
		%Returns true on success
            try
                obj.experiment = struct('metaData', [], 'specimenData', [], 'testData', [], 'calculatedData', []);
                result = true;
            catch
                warning([class(obj), ' - ', 'Cache could not be cleared successfull!']);
                result = false;
            end
		end 
        
		function dataTable = getFilteredDataTable(obj, experimentNo)
		%Returns a timetable containing all available datasets for the given experiment number
			
			%Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
			if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
			end
			
            dataTable = obj.experiment(experimentNo).testData.getFilteredDataTable;
		end
		
		
		function dataTable = getOriginalDataTable(obj, experimentNo)
		%Returns a timetable containing all available datasets for the given experiment number (without filtering)
			
			%Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
			if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
			end
			
            dataTable = obj.experiment(experimentNo).testData.getOriginalDataTable;
		end
		
		function dataTable = getTemperatures(obj, experimentNo)
        %Returns a timetable containing all temperature data.
				
			%Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
			if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
			end
			
			dataTable = obj.experiment(experimentNo).testData.getAllTemperatures;
		end
		
		function dataTable = getPressureData(obj, experimentNo) 
        %Returns a timetable containing all relative pressure data: time, runtime
        %fluidPressureRel, hydrCylinderPressureRel, confiningPressureRel
            
			%Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
			if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
			end
			
			dataTable = obj.experiment(experimentNo).testData.getAllPressureRelative;
		end
		
		function dataTable = getBassinPumpData(obj, experimentNo) 
        %Returns a timetable containing all relative pressure data: time, runtime
        %fluidPressureRel, hydrCylinderPressureRel, confiningPressureRel
            
			%Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
			if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
			end
			
			dataTable = obj.experiment(experimentNo).testData.getBassinPumpData;
		end
		
		function dataTable = getStrain(obj, experimentNo)
        %Returns a timetable containing deformation data of the specimen: time, runtime
        %strainSensor1Rel, strainSensor2Rel, strainSensorMean
		%Input parameters:
        %   experimentNo : number of the experiment
		%Returns a table containing all strain data
		
            %Check for correct input parameters            
            if nargin < 2
                error([class(obj), ' - ', 'Not enough input arguments. One input parameter have to be handed over: experimentNo']);
            end

            %Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
			if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
			end
			
			%Check whether the experiment has already been loaded.
            if ~obj.isExperimentLoaded(experimentNo)
                warning([class(obj), ' - ', 'Experiment number ', int2str(experimentNo), ' has not been loaded yet.']);
                result = [];
                return;
            end
		
			dataTable = obj.experiment(experimentNo).testData.getDeformationRelative();    

            %Calculating the mean deformation influenced by deformatoin
            %sensor 1 and 2. NaN entrys will be ignored.
            dataTable.strainSensorsMean = mean([dataTable.strainSensor1Rel, dataTable.strainSensor2Rel], 2, 'omitnan');
            dataTable.Properties.VariableUnits{'strainSensorsMean'} = 'mm';
            dataTable.Properties.VariableDescriptions {'strainSensorsMean'} = 'Mean relative deformation from sensor 1 and 2, zeroed at the beginning of the experiment';
		end
		
        function result = getPermeability(obj, experimentNo, timestep, debug)
        %This function calculates the permeability and returns a
        %timetable containing the permeability and runtime. Alpha is included.
        %Input parameters:
        %   experimentNo : number of the experiment
        %   timestep: timestep between to calculation point of perm
        %Returns a table containing permeability
		
            %Check for correct input parameters
            if nargin == 2
                warning('Set timestep to default: 5 minutes');
                timestep = 5;
				debug = false;
			end
			
			if nargin == 3
                debug = false;
            end
            
            if nargin < 2
                error([class(obj), ' - ', 'Not enough input arguments. One input parameter have to be handed over: experimentNo']);
            end

            %Check if the variable experimentNo is valid
            validateExpNo = obj.validateExperimentNoInput(experimentNo);
            if ischar(validateExpNo)
                error([class(obj), ' - ', validateExpNo]);
            end
        
            %Check whether the experiment has already been loaded.
            if ~obj.isExperimentLoaded(experimentNo)
                warning([class(obj), ' - ', 'Experiment number ', int2str(experimentNo), ' has not been loaded yet.']);
                result = [];
                return;
            end
            
            try
                %Catch all relevant data as timetable
                flowMassData = obj.getFlowMassData(experimentNo, timestep); % flow mass
				strainData = obj.getStrain(experimentNo); % probe deformation
				probeInitHeight = obj.experiment(experimentNo).specimenData.height.value/100; % probe height in m
				probeDiameter = obj.experiment(experimentNo).specimenData.diameter.value/100; % probe height in m
				
                dataTable = synchronize(flowMassData, strainData(:,'strainSensorsMean')); 
                
				%Check if fluid outflow temperature exists. Otherwise a standard temperature of 18�C will be used for further
				%calculations.
                if isnan(dataTable.fluidOutTemp)
                    dataTable.fluidOutTemp = zeros(size(dataTable,1),1)+18;
                    disp([class(obj), ' - ', 'Fluid outflow temperature set to 18�C.']);
                end
                dataTable.fluidDensity = obj.waterDensity(dataTable.fluidOutTemp); %get fluid (water) density

                %Retime the dataTable to given timestep
                time = (dataTable.datetime(1) : minutes(timestep) : dataTable.datetime(end));
                dataTable = retime(dataTable,time,'linear');
				
				%Add probeHeight (variable) and crosssection area (constant)
                dataTable.probeHeigth = probeInitHeight - (dataTable.strainSensorsMean ./ 1000);
                crossSecArea = ((probeDiameter) / 2)^2 * pi; %crosssection


				gravity = 9.81; %Gravity m/s� or N/kg

				dataTable.deltaPressureHeight = (dataTable.fluidPressureRel .* 100000) ./ (dataTable.fluidDensity .* gravity); %Pressure difference h between inflow and outflow in m
				dataTable.fluidFlowVolume = (dataTable.flowMassDiff ./ dataTable.fluidDensity); %water flow volume Q in m�

				dataTable.permCoeff = ((dataTable.fluidFlowVolume ./ seconds(dataTable.timeDiff)) .* dataTable.probeHeigth) ./ (dataTable.deltaPressureHeight .* crossSecArea); %calculate permeability
				dataTable.permCoeff = max(0, dataTable.permCoeff);

				%Normalize permeability to a reference temperature of 10 �C
				dataTable.Itest = (0.02414 * 10.^((ones(size(dataTable.permCoeff)) * 247.8) ./ (dataTable.fluidOutTemp + 133)));
				dataTable.IT = (0.02414 * 10.^((ones(size(dataTable.permCoeff)) * 247.8) ./ (10 + 133)));%Using reference temperature of 10 �C
				dataTable.alpha = dataTable.Itest ./ dataTable.IT;
				dataTable.permCoeffAlphaCorr = dataTable.permCoeff .* dataTable.alpha;
				
				%Create result table
				if debug
					permeability = dataTable;
				else
					permeability = dataTable(:,{'runtime'});

					permeability.permeability = dataTable.permCoeffAlphaCorr;
					permeability.Properties.VariableUnits{'permeability'} = 'm/s';
					permeability.Properties.VariableDescriptions{'permeability'} = 'Coefficient of permeability alpha corrected to 10�C';

					permeability.alphaValue = dataTable.alpha;
					permeability.Properties.VariableUnits{'alphaValue'} = '-';
					permeability.Properties.VariableDescriptions{'alphaValue'} = 'Rebalancing factor to compare permeabilitys depending on the fluid temperature';
				end
				
				result = permeability;
            catch
                warning([class(obj), ' - ', 'Calculating permeability FAILED!']);
                result = [];
            end
            
        end

    end
end
