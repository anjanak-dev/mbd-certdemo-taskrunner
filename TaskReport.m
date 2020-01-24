classdef TaskReport
    %JenkinsReport
    %
    % Generate a summary report in XML format that can be processed by the
    % Jenkins Sumary Display Plugin. See the following linke for details
    % https://wiki.jenkins.io/display/JENKINS/Summary+Display+Plugin
    
    % A seperate XML file has to be created for each section.  There can be
    % only one <section> tag per XML file.
    
    methods
        function obj = TaskReport()
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
        end
        
        function createTaskTable(~, data)
            %createModelStdsTable Create an table that holds results of
            %Model Standards check with Model Advisor for each referenced
            %model.
            %

            DocNode = com.mathworks.xml.XMLUtils.createDocument('section');
            SectionNode = DocNode.getDocumentElement();
            SectionNode.setAttribute('name','Task Summary Report');
            
            ColumnHeaders = {'Task Name', 'Pass'};
            TableData = data;
            TaskReport.createTable(DocNode, SectionNode, ColumnHeaders, TableData );
            
            xmlwrite(fullfile(pwd, 'TaskReport.xml'), DocNode);
        end
    end
    
    methods(Static)
        function tableNode = createTable( DocNode, SectionNode, ColumnHeaders, Data )
            % creatTable - create a XML table in Jenkins Summary Report
            % format
            %
            % 
            
            tabNode = DocNode.createElement('tab');
            tabNode.setAttribute('name', 'Task Summary');
            SectionNode.appendChild(tabNode);
            
            tableNode = DocNode.createElement('table');
            tabNode.appendChild(tableNode);
            
            % create header row
            tableRowNode = DocNode.createElement('tr');
            tableNode.appendChild(tableRowNode);
            
            for j=1:numel(ColumnHeaders)
                tableDataNode = DocNode.createElement('td');
                tableDataNode.setAttribute('value', ColumnHeaders{j});
                tableRowNode.appendChild(tableDataNode);
            end
            
            % create a row for each task
            for i=1:size(Data,1)
                tableRowNode = DocNode.createElement('tr');
                tableNode.appendChild(tableRowNode);
                for j=1:size(Data,2)
                    tableDataNode = DocNode.createElement('td');
                    if isnumeric(Data{i,j})
                        Data{i,j} = num2str(Data{i,j});
                    end    
                    tableDataNode.setAttribute('value', Data{i,j});
                    % set cell background color to red or yellow
                    if (strcmpi(ColumnHeaders{j}, 'Pass')) && str2double(Data{i,j}) == 0 
                        tableDataNode.setAttribute('bgcolor', 'red');                        
                    end
                    
                    if (strcmpi(ColumnHeaders{j}, 'Pass')) && str2double(Data{i,j}) == 1
                        tableDataNode.setAttribute('bgcolor', 'green');                        
                    end
                    
                    tableRowNode.appendChild(tableDataNode);
                end
            end

        end
    end
end

