classdef ExperimentsMetaData < handle
%Class to handle the meta data of MERID triaxial experiments. The
%experiment number has to be given while creating the class object.
%All metadata information like start and end time, comments or a
%description can be read directly from the class.
%Within the class the data will be saved in a table (metaDataTable). All
%depending variables like (description, short, etc.) are empty. They are some kind of
%proxy values to be able to work with the values as if they where saved in
%the variables.
    
    properties (SetAccess = immutable)
        experimentNo; %Number of the experiment the metadata in this object contains to.
    end
    
    properties (SetAccess = private)
        description; %Proxyvariable for description in metadata. Data is only saved in metaDataTable.
        comment; %Proxyvariable for comments in metadata. Data is only saved in metaDataTable.
        timeStart; %Proxyvariable for start time in metadata. Data is only saved in metaDataTable.
        timeEnd; %Proxyvariable for end time in metadata. Data is only saved in metaDataTable.
        short; %Proxyvariable for short name in metadata. Data is only saved in metaDataTable.
        specimenId; %Proxyvariable for specimen id in metadata. Data is only saved in metaDataTable.
        fluidPressure; %Proxyvariable for fluid pressure used in metadata. Data is only saved in metaDataTable.
        confiningPressure; %Proxyvariable for confining pressure used in metadata. Data is only saved in metaDataTable.
        metaDataTable; %Table containing all metadata from database
        timelog; %Table containing the time log for the given experiment: experiment_no, retrospective, time, description
		testRigData; %Table containing all test rig information from database
		initPermCoeff; %Proxyvariable for initial permeability coefficient in metadata.
        
    end
    
    methods
        function obj = ExperimentsMetaData(experimentNo)
        %The experiment number (immutable) has to be set int the constructor and can
        %not be changed later.
            obj.experimentNo = experimentNo;
        end
        
        %SETTER
        function obj = setMetaDataAsTable(obj, metaDataTable)
        %Set all metadata for the experiment into the object.
        %Input parameter: table with metaData
            try
                %Check if metadata fits to set experiment number
                if (metaDataTable.experimentNo(1) == obj.experimentNo)
                    obj.metaDataTable = metaDataTable;

                    obj.metaDataTable.Properties.VariableUnits{'pressureFluid'} = 'kN/m�';
                    obj.metaDataTable.Properties.VariableUnits{'pressureConfining'} = 'kN/m�';

                    %Recasting datetime-String to real Datetime in Matlab
                    obj.metaDataTable.timeStart = datetime(obj.metaDataTable.timeStart,'InputFormat','yyyy-MM-dd HH:mm:ss.S');
                    obj.metaDataTable.timeEnd = datetime(obj.metaDataTable.timeEnd,'InputFormat','yyyy-MM-dd HH:mm:ss.S');

                    disp([class(obj), ': ', 'Metadata set sucessfully']);
                else
                   error('%s: Given metadata do not fit to set experiment number', class(obj));
                end
            catch E
                warning('%s: Error while setting meta data', class(obj));
            end
		end
        

		function obj = setTestRigDataAsTable(obj, testRigTable)
        %Set time log for the experiment into the object.
        %Input parameter: table with time log
            try
                    obj.testRigData = testRigTable;
					
					obj.testRigData.Properties.VariableUnits{'diameterMax'} = 'm';
					obj.testRigData.Properties.VariableUnits{'heightMax'} = 'm';
					obj.testRigData.Properties.VariableUnits{'axialCylinderKgMax'} = 'kg';
					obj.testRigData.Properties.VariableUnits{'axialCylinderPMax'} = 'N/m�';
					obj.testRigData.Properties.VariableUnits{'confiningPMax'} = 'N/m�';
					obj.testRigData.Properties.VariableUnits{'initPermCoeff'} = 'm/s';

                    disp([class(obj), ': ', 'Test rig data set sucessfully']);

            catch E
                warning([class(obj), ': ', 'Error while setting test rig data']);
            end
        end
		
        function obj = setTimeLogAsTable(obj, timelogTable)
        %Set time log for the experiment into the object.
        %Input parameter: table with time log
            try
                %Check if timelog fits to set experiment number
                if (timelogTable.experimentNo(1) == obj.experimentNo)
                    obj.timelog = timelogTable;

                    %Recasting datetime-String to real Datetime in Matlab
                    obj.timelog.time = datetime(obj.timelog.time,'InputFormat','yyyy-MM-dd HH:mm:ss.S');


                    disp([class(obj), ': ', 'Time log set sucessfully']);
                else
                   error('%s: Given time log do not fit to set experiment number', class(obj));
                end
            catch E
                warning('%s: Error while setting time log', class(obj));
            end
        end
        
        function obj = setDescription(obj,description) 
        %Set a description for the experiment into the metadata. The
        %information will not be saved into the variable 'description'. It
        %is saved into the variable metaDataTable instead.
        %Input parameter: description as char
            obj.metaDataTable.description(1) = cellstr(description);
        end
        
        function obj = setComment(obj,comment) 
        %Set a comment for the experiment into the metadata. The
        %information will not be saved into the variable 'comment'. It
        %is saved into the variable metaDataTable instead.
        %Input parameter: comment as char
            obj.metaDataTable.comment(1) = cellstr(comment);
        end
        
        function obj = setTime_start(obj,timeStart) 
        %Set a start time for the experiment into the metadata. The
        %information will not be saved into the variable 'timeStart'. It
        %is saved into the variable metaDataTable instead.
        %Input parameter: start time as char
            obj.metaDataTable.timeStart(1) = cellstr(timeStart);
        end
        
        function obj = setTime_end(obj,timeEnd)
        %Set a end time for the experiment into the metadata. The
        %information will not be saved into the variable 'timeEnd'. It
        %is saved into the variable metaDataTable instead.
        %Input parameter: end time as char
            obj.metaDataTable.timeEnd(1) = cellstr(timeEnd);
        end
        
        function obj = setShort(obj,short) 
        %Set a short name for the experiment into the metadata. The
        %information will not be saved into the variable 'short'. It
        %is saved into the variable metaDataTable instead.
        %Input parameter: short name as char
            obj.metaDataTable.short(1) = cellstr(short);
        end
        
        %GETTER
        function experimentNo = get.experimentNo(obj) 
            experimentNo = obj.experimentNo;
        end
        
        function description = get.description(obj) 
            description = obj.metaDataTable.description{1};
        end
        
        function comment = get.comment(obj) 
            comment = obj.metaDataTable.comment{1};
        end
        
        function timeStart = get.timeStart(obj) 
            timeStart = obj.metaDataTable.timeStart(1);
        end
        
        function timeEnd = get.timeEnd(obj) 
            timeEnd = obj.metaDataTable.timeEnd(1);
        end
        
        function short = get.short(obj) 
            short = obj.metaDataTable.short{1};
        end
        
        function specimenId = get.specimenId(obj) 
            specimenId = obj.metaDataTable.specimenId;
        end
        
        function pressureFluid = get.fluidPressure(obj) 
            pressureFluid = obj.metaDataTable.pressureFluid;
        end
        
        function pressureConfining = get.confiningPressure(obj) 
            pressureConfining = obj.metaDataTable.pressureConfining;
		end
        
		function testRigData = get.testRigData(obj) 
            testRigData = obj.testRigData;
		end
		
		function initPermCoeff = get.initPermCoeff(obj) 
            initPermCoeff = obj.metaDataTable.initPermCoeff;
		end
		
        function timelog = get.timelog(obj) 
            %Getter for the experiments time log.
            %Column 'retrospective' contains a boolean value that tells you whether the 
            %information was recorded during or after the experiment.
            timelog = obj.timelog;
           
        end
        
        
        
    end
end