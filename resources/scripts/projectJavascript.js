/**
 * @author Andor Lundgren
 * @fileOverview In the ANDS project javascript related to the webpage is devided into two files, projectJavascript.js and projectJquery.js.
 * All functions that uses anything with jQuery syntax are in the projectJquery.js file and the rest is here.
 * Most of code in projectJavascript.js are used in the analyse view which lets you analyse your data. 
 * In the analyse view you have the possibility to drag and drop existing files into command inputs and because it all is done in 
 * javascript all objects on the server have to have a representation object in the javascript. It is because of this the javascript is quite large.
 * All representation of database objects are classes and all classes are joined to one large class that is used to create a command, the CommandConstructor.
 */

// global, that are initialized with data from server, will grow and shrink for each action taken (add, remove and update a command)
var clientCommandConstructor = new CommandConstructor('clientCommandConstructor'); // used when user creates a command

/**
 * The command construtor contains all values for describing a command and processes used for creating a bash command.
 * A processes are associated with a command and several processes may use the same command so in this object it may not be neccessary to remove
 * the command when you remove a process, but if you do you have to check that no other process are using that command.
 * In the same manner, if you are going to add a command to the CommandConstructor the CommandConstructor must first check to see if the command already exist.
 * @class CommandConstructor contains all values for describing a command and processes used for creating a bash command
 * @property {string} name name is the name of the CommandConstructor and is used when wanting to access the object from a client click method( You pass the name, and use function.name on the click).
 * @property {Commands} commands commands is a Commands class object.
 * @property {Dependencies} dependencies dependendencies is a Dependencies class object.
 * @property {Filetypes} filetypes filetypes is a Filetypes class object.
 * @property {Parameters} parameters parameters is a Parameters class object.
 * @property {Parametertypes} parametertypes parametertypes is a Parameters class object.
 * @property {Processes} processes processes is a Processes class object.
 * @property {Processparametervalues} processparametervalues processparametervalues is a Processparametervalues class object.
 * @property {Softwares} softwares softwares is a Softwares class object.
 * @property {Previewgraph} previewgraph previewgraph is a Previewgraph class object that has the settings used to display the graph.
 * @property {Commandlines} commandlines commandlines is a Commandlines class object that is used when updating the previewgraph.
 */
function CommandConstructor(name) {
    this.name = name;
    this.commands               = new Commands();
    this.dependencies           = new Dependencies();
    this.filetypes              = new Filetypes();
    this.parameters             = new Parameters();
    this.parametertypes         = new Parametertypes();
    this.processes              = new Processes();
    this.processparametervalues = new Processparametervalues();
    this.softwares              = new Softwares();
    this.previewgraph           = new Previewgraph();
    this.commandlines           = new Commandlines();
    
    /** adds a command to the commands object*/
    this.addCommand = function(command){
        if( ! this.commands.get(command.id) ){
            this.commands.add(command);
        }
    }
    /** adds a dependency to the dependencis object*/
    this.addDependency = function(dependency){
        if( ! this.dependencies.getWithProcessIdAndParentId(dependency.process_id, dependency.parent_process_id) ){
            this.dependencies.add(dependency);
        }
    }
    /** adds a filetype to the filetypes object*/
    this.addFiletype = function(filetype){
        if( ! this.filetypes.get(filetype.id) ){
            this.filetypes.add(filetype);
        }
    }
    /** adds a parameter to the parameters object*/    
    this.addParameter = function(parameter){
        if( ! this.parameters.get(parameter.id) ){
            this.parameters.add(parameter);
        }
    }
    /** adds a parametertype to the parametertypes object*/    
    this.addParametertype = function(parametertype){
        if( ! this.parametertypes.get(parametertype.id) ){
            this.parametertypes.add(parametertype);
        }
    }
    /** adds a process to the processes object*/
    this.addProcess = function(process){
        if( ! this.processes.get(process.id) ){
            this.processes.add(process);
        }
    }
    /** adds a processparametervalue to the processparametervalues object*/
    this.addProcessparametervalue = function(processparametervalue){
        if( ! this.processparametervalues.get(processparametervalue.id) ){
            this.processparametervalues.add(processparametervalue);
        }
    }
    /** adds a software to the softwares object*/    
    this.addSoftware = function(software){
        if( ! this.softwares.get(software.id) ){
            this.softwares.add(software);
        }
    }
    
    /** createDummyValues creates processParameterValues for each mandatory command*/
    this.createDummyValues = function(){
        // if loaded with a command, dummy values should be inserted to process and processparametervalues
        for( var i = 0; i < this.commands.command.length; i++){
            var command = this.commands.command[i];
        
            var process   = new Process();
            var processId = this.createDummyProcessId();
            var projectId = this.getLoggedInProjectId();
            var personId  = this.getLoggedInPersonId();
            var type      = 1;// default as template (template == 1, done == 2, processing == 3)
            process.set( processId, command.iname, command.description, command.id, projectId, personId, type );  // have used the commands name and description when creating the process
            this.processes.add(process);
        
            var parameters = this.parameters.getWithCommandId(command.id);    

            for( var j = 0; j < parameters.parameter.length; j++){
                var parameter = parameters.parameter[j];
    
                if(parameter.is_mandatory == 1){
                    if(parameter.getMinNumberItems() == 0){
                        var ppv = new Processparametervalue();
                        var id = this.createDummyProcessParameterValueId();
                        ppv.set(id, processId, parameter.id, '', 0);
                        this.processparametervalues.add(ppv); // add to commandConstructor object
                    }
                    
                    for(var k=0; k < parameter.getMinNumberItems(); k++){// populate with minimum number of parameter values
                        // create dummy processParameterValue
                        var ppv = new Processparametervalue();
                        var id = this.createDummyProcessParameterValueId();
                        ppv.set(id, processId, parameter.id, '', k);
                        this.processparametervalues.add(ppv); // add to commandConstructor object
                    }
                }
            }
        }
    }
    
    /** gets project_id from a hidden on the page 
     * @returns {numeric} projectId 
     */
    this.getLoggedInProjectId = function(){
        return document.getElementById('hiProjectId').value;
    }
    /** gets logged_in person_id from a hidden on the page
     * @returns {numeric} personId 
     */
    this.getLoggedInPersonId = function(){
        return document.getElementById('hiPersonId').value;
    }
    /** gets process type (template or job) from hidden on the page
     * @function 
     * @returns {numeric} processType (should be 1 or 2, if set correctly) 
     */
    this.getProcessType = function(){
        return document.getElementById('hiProcessType').value;
    }
    
    /** creates a unique processParameterValue. It will be unique both on the page and in the commandConstructor object. 
     * This value will only be used in the client, when inserted into database it will get a real value.
     * @function 
     * @returns {string} id, in the form 'dummyId' + RAND 
     */
    this.createDummyProcessParameterValueId = function(){
        var id;
        var foundUnique = false;
        while( !foundUnique ){
            var id = createUniqueId('dummyId'); // get unique on the page, if it has a text before number there will also be no collision with the server table ids which is a serial
            foundUnique = true;
            for(var i = 0; i < this.processparametervalues.processparametervalue.length; i++){
                if(this.processparametervalues.processparametervalue.id == id){
                    foundUnique = false;
                    break;
                }
            }
        }
        return id
    }
    /** creates a unique process_id. It will be unique both on the page and in the commandConstructor object. 
     * This value will only be used in the client, when inserted into database it will get a real value.
     * @function 
     * @returns {string} id, in the form 'dummyId' + RAND 
     */
    this.createDummyProcessId = function(){
        var id;
        var foundUnique = false;
        while( !foundUnique ){
            var id = createUniqueId('dummyId');
            foundUnique = true;
            for(var i = 0; i < this.processes.process.length; i++){
                if(this.processes.process.id == id){
                    foundUnique = false;
                    break;
                }
            }
        }
        return id
    }

    /** adds all missing objects from input commandConstructor to this object, it can not be reversed. 
     * To be able to remove values from a commandConstructor you have to check that the value is not in use in any of the remaining commands and processes
     */
    this.add = function(commandConstructor){
        for(var i = 0; i < commandConstructor.commands.command.length; i++){                                // commands
            this.addCommand(commandConstructor.commands.command[i]);
        }
        for(var i = 0; i < commandConstructor.dependencies.dependency.length; i++){                         // dependencies
            this.addDependency(commandConstructor.dependencies.dependency[i]);
        }
        for(var i = 0; i < commandConstructor.filetypes.filetype.length; i++){                              // filetypes
            this.addFiletype(commandConstructor.filetypes.filetype[i]);
        }
        for(var i = 0; i < commandConstructor.parameters.parameter.length; i++){                            // parameters
            this.addParameter(commandConstructor.parameters.parameter[i]);
        }
        for(var i = 0; i < commandConstructor.parametertypes.parametertype.length; i++){                    // parametertypes
            this.addParametertype(commandConstructor.parametertypes.parametertype[i]);
        }
        for(var i = 0; i < commandConstructor.processes.process.length; i++){                               // processes
            this.addProcess(commandConstructor.processes.process[i]);
        }
        for(var i = 0; i < commandConstructor.processparametervalues.processparametervalue.length; i++){    // processparametervalues
            this.addProcessparametervalue(commandConstructor.processparametervalues.processparametervalue[i]);
        }
        for(var i = 0; i < commandConstructor.softwares.software.length; i++){                              // softwares
            this.addSoftware(commandConstructor.softwares.software[i]);
        }
    }

    /** creates a process and its processparametervalues and adds it to the commandconstructor from a commandId
     * it is used when a user adds a command to the drag and drop table
     */
    this.createProcessWithCommandId = function(commandId){
        
        // create process
        var processId = this.createDummyProcessId();
        process.set( processId, '', '', commandId );        // id, iname, description, command_id
        this.processes.add(process);
        
        // create minimum number of values
        var parameters = this.parameters.getWithCommandId(command.id);    

        for( var j = 0; j < parameters.parameter.length; j++){
            var parameter = parameters.parameter[j];

            if(parameter.is_mandatory == 1){
                if(parameter.getMinNumberItems() == 0){  // mandatory objects that have 0 items should have a value if it is used
                    var ppv = new Processparametervalue();
                    var id = this.createDummyProcessParameterValueId();
                    ppv.set(id, processId, parameter.id, '', 0);
                    this.processparametervalues.add(ppv); // add to commandConstructor object
                }
                
                for(var k=0; k < parameter.getMinNumberItems(); k++){// populate with minimum number of parameter values
                    // create dummy processParameterValue
                    var ppv = new Processparametervalue();
                    var id = this.createDummyProcessParameterValueId();
                    ppv.set(id, processId, parameter.id, '', k);
                    this.processparametervalues.add(ppv); // add to commandConstructor object
                }
            }
        }
    }
    
    /** removes the process, it's process_dependency and process_parameter_values
     * it will not remove the command used (other processes may use it)
     */
    this.removeProcessWithValues = function(processId){
        var process = this.processes.get(processId);
        this.processes.remove(process);                             // remove process
        var dependencies = this.dependencies.get(processId);        // returns a dependencies object, a process may have several dependencies
        for(var i = 0; i < dependencies.dependency.length; i++){    // remove process_dependencies
            this.dependencies.remove( dependencies.dependency[i] ); 
        }
        var processParameterValues = this.processparametervalues.getWithProcessId(processId);      
        for(var i = 0; i < processParameterValues.processparametervalue.length; i++){    // remove processparametervalues
            this.processparametervalues.remove( processParameterValues.processparametervalue[i] ); 
        }
    }

    /** steps through the drag and drop table and gets all dragged items values and updates the commandConstructor's processparametervalues.value*/
    this.updateProcessParameterValuesFromTable = function(tableId){
        var tbl = document.getElementById(tableId);
        for (var i = 0, row; row = tbl.rows[i]; i++) {              // create array of unique id's for each row (all the steps)
            var id = getRowId(row);
            var inputsDiv  = document.getElementById("inputs"  + id);     // wrapping div for inputs  on this table row
            var outputsDiv = document.getElementById("outputs" + id);     // wrapping div for outputs on this table row

            // for inputs
            if(inputsDiv){
                var divs = inputsDiv.getElementsByTagName('div');
                for(var j = 0; j < divs.length; j++) {
                    if( divs[j].id && divs[j].id.indexOf("target") != -1 ){
                        // a target == droppable
                        var fileIds = [];
                        var div = divs[j].getElementsByTagName('div');
                        for(var k = 0; k < div.length; k++) {
                            if( div[k].id && div[k].id.indexOf("divObj") != -1 ){
                                // a dragged file
                                fileIds.push( isDraggedItemAnOutputFromAProcess(div[k]) ? 'NEWFILE' + getObjectFileId(div[k]) : getObjectFileId(div[k]) );
                            }
                        }
                        var processParameterValueInputId = getDroppableProcessParameterValueInputId(divs[j]);
                        // it will only update those values that exist in the table that has a value in the commandconstructor
                        // if a item has been removed/added in the parameterswindow view the commandconstructor will have one less/more processparametervalue but not in the draganddroptable
                        // that is why we always force a refresh on the draganddroptable after a removeInputFromInputs has been called from the parameters window
                        if( this.processparametervalues.get(processParameterValueInputId) ){
                            this.processparametervalues.get(processParameterValueInputId).value = fileIds.join(' ');
                        }
                    }
                }
            }
            // for outputs
            if(outputsDiv){
                var divs = outputsDiv.getElementsByTagName('div');
                for(var l = 0; l < divs.length; l++) {
                    if( divs[l].id && divs[l].id.indexOf("div") != -1 ){
                        // a output
                        var fileIds = [];
                        var inputs = divs[l].getElementsByTagName('input');
                        var fileId;
                        var ppvId;
                        for(var m = 0; m < inputs.length; m++) {
                            if( inputs[m].id && inputs[m].id.indexOf("fileIdProcessOutput") != -1 ){
                                fileId = "NEWFILE" + inputs[m].value;
                            }
                            else if( inputs[m].id && inputs[m].id.indexOf("processParameterValueOutputId") != -1 ){
                                ppvId = inputs[m].value;
                            }
                        }
                        if( this.processparametervalues.get(ppvId) ){
                            this.processparametervalues.get(ppvId).value = fileId;
                        }
                    }
                }
            }
        }  
    }

    /** Updates the previewgraph objects commandlines before getting the graphviz JSON representation of the drag and drop table.
     * It is used when the graph preview is populated with command lines instead of process name.
     * instead of get JSON from previewGraph to send to server to get svg it first gets the commandlines 
     */
    this.updatePreviewGraphWithCommandlines = function(commandlines){
        this.commandlines = commandlines;
        getGraphvizSvg(this, JSON.stringify(this.createJsonForGraphviz()));     
    }
    
    /** updatePreviewGraph will call functions that in the end will update the graphpreview.
     *   If the previewGraph is set to not show the commands execution line instead of the process name on the nodes it will:
     *       1. Call function that gets the JSON represenation of the drag and drop table
     *       2. Call function that gets the SVG from server from that JSON and updates the graph
     *   If it is set to show the commands execution:
     *       1. Call function that updates the commandlines which calls the methods above when the commandlines are updated
     */
    this.updatePreviewGraph = function(){
        if( this.previewgraph.addCommandsToGraph == true ){
            // update commands, and after that call updatePreviewGraphWithCommandlines(commandlines) above is called from the ajax call
            var updatePreviewGraphAfterResponse = true;
            getCommandLinesPreview(this, updatePreviewGraphAfterResponse);
        }
        else{
            getGraphvizSvg(this, JSON.stringify(this.createJsonForGraphviz()));
        }
    }

    /** creates and returns JSON for graphviz application from the drag and drop table
     * @returns {object} JSON describing the previewGraph in a graphviz syntax
     */
    this.createJsonForGraphviz = function(){
        this.previewgraph.createGraphFromTable(this, 'tblProcesses');
        return this.previewgraph.toJson();
    }
}

/** createTable creates the table at the spot whereToInsert
 * if draggedFiles is true it will match the processparametervalue.values to the outputs and if will copy the output to that input 
 */
function createTable(commandConstructor, whereToInsert, addDraggedFiles){
    // clear whereToInsert of content (if old table exist it could lead to problems because getElementById is used when addDrggedFiles is used)
    document.getElementById(whereToInsert).innerHTML = '';
    
    // add table     
    var tblThead = createTableHead(['Command', 'Input', 'Output']);                                      // create header
    var tblTbody = createTableBody(commandConstructor);
    var table    = '<table id="tblProcesses" class="tblCreateAnalyse">' + tblThead + tblTbody + '</table>';
    document.getElementById(whereToInsert).innerHTML = table;
    
    if(addDraggedFiles){
        addDraggedFilesToTable(commandConstructor, 'tblProcesses');
    }
}

/** createTableHead creates the table head for the drag and drop table 
 * @returns {string} html containing thead
 */
function createTableHead(tableHeadArray){
    var tableHead = '<thead><tr>';
    for( var i = 0; i < tableHeadArray.length; i++){
        tableHead += '<th>' + tableHeadArray[i] + '</th>';
    }
    tableHead += '</tr></thead>'
    return tableHead;
}

/** createTableBody creates the table tbody for the drag and drop table 
 * @returns {string} html containing tbody
 */
function createTableBody(commandConstructor){
    var tbody = '<tbody>';
    tbody    += createTableRows(commandConstructor);
    tbody    += '</tobdy>';
    return tbody;
}

/** function that adds files to the drag and drop table
 * It must be called after the rows has been added (otherwise it will not find the command outputs needed to be dragged).
 * The function tries to find the inputs processparametervalue.value in the commandConstructor in the table, 
 * if it finds the output or the file it will add it to the inputs and also add the dependency.
 */
function addDraggedFilesToTable(commandConstructor, tableId){
    var tbl = document.getElementById(tableId);
    for (var i = 0, row; row = tbl.rows[i]; i++) {                      // create array of unique id's for each row (all the steps)
        var id = getRowId(row);
        var inputsDiv  = document.getElementById("inputs" + id);        // wrapping div for inputs  on this table row

        // for inputs
        if(inputsDiv){
            var divs = inputsDiv.getElementsByTagName('div');

            for(var j = 0; j < divs.length; j++) {
                if( divs[j].id && divs[j].id.indexOf("target") != -1 ){
                    
                    var processParameterValueInputId = getDroppableProcessParameterValueInputId(divs[j]);
                    if(processParameterValueInputId){ // if it has a value try to copy it
                        var processParameterValue = commandConstructor.processparametervalues.get(processParameterValueInputId);
                        // the processParameterValue could have several files in it (even if it is not allowed to have several files in a input when saved it is possible in while dragging them around)
                        if( processParameterValue.value != ''){
                            var files = processParameterValue.value.split(' ');
                            for(var f = 0; f<files.length; f++){
                                var fileName = files[f];
                                var fileWasAOutputFromAProcess = false; // used to ensure correct class to draggable item if it was an output
                                var outputProcessId;
                                // 1. get source div that should be copied from
                                var fileDiv = '';
                                if(fileName.indexOf('NEWFILE') == -1){                   // the file mentioned in processParameterValue is a file, not a output from a process
                                    fileDiv = document.getElementById('div' + fileName); // get file object
                                }
                                else{
                                    fileWasAOutputFromAProcess = true;
                                    // get div from the output of a process
                                    // the input has id fileIdProcessOutputRAND with value SOMENUMBER, in the processParameterValue the output has format NEWFILESOMENUMBER
                                    var fileId = fileName.replace("NEWFILE", "");// extract the SOMENUMBER
                                    // get the file was dragged from the table
                                    
                                    
                                    var tableId2 = 'tblProcesses';
                                    var tbl2 = document.getElementById(tableId2);
                                    for (var k = 0, row2; row2 = tbl2.rows[k]; k++) {              // create array of unique id's for each row (all the steps)
                                        var rowId = getRowId(row2);
                                        var outputsDiv = document.getElementById("outputs" + rowId);     // wrapping div for outputs on this table row
                                        // for outputs
                                        if(outputsDiv){
                                            var divs2 = outputsDiv.getElementsByTagName('div');
                                            for(var l = 0; l < divs2.length; l++) {
                                                if( divs2[l].id && divs2[l].id.indexOf("div") != -1 ){
                                                    //alert('found a output div with id: ' + divs2[l].id + ' will search for file with id: ' + fileId );
                                                    // a output
                                                    var inputs = divs2[l].getElementsByTagName('input');
                                                    for(var m = 0; m < inputs.length; m++) {
                                                        if( inputs[m].id && inputs[m].id.indexOf("fileIdProcessOutput") != -1 && inputs[m].value == fileId){
                                                            fileDiv = divs2[l];                 // store the div the output has
                                                            //alert('going to use' + divs2[l].toString());
                                                        }
                                                        if( inputs[m].id && inputs[m].id.indexOf("processParameterValueOutputId") != -1 ){
                                                            outputProcessId = commandConstructor.processparametervalues.get(inputs[m].value).process_id; // store the process_id it has for add of dependency
                                                        }
                                                    }
                                                    if(fileDiv != ''){
                                                        break;
                                                    }
                                                }
                                            }
                                            if(fileDiv != ''){
                                                break;
                                            }
                                        }
                                    }
                                }

                                if(fileDiv != ''){
                                    // clone object
                                    var newObject = fileDiv.cloneNode(true);
                                    // create unique id for the object
                                    newObject.id = createUniqueId('divObj');
                                    
                                    // replace objects fileIdRAND or fileIdProcessOutputRAND id with a new RAND
                                    replaceNodeFileIdAndFileTypeId(newObject);
                                    
                                    // remove permanent as class so the object can be moved several times
                                    var newClassName = fileDiv.className;
                                    newClassName = newClassName.replace("permanent", ""); 
                                    
                                    // if it was an output, add the class of draggableOutputItem
                                    newClassName = newClassName.replace("okToProcess", "draggableOutputItem"); 
                                    
                                    // because the file may not have updated the outputs classes (with a refresh css
                                    if(fileWasAOutputFromAProcess && newClassName.indexOf("draggableOutputItem") == -1){
                                        newClassName += ' draggableOutputItem';
                                    }
                                    
                                    newObject.className = newClassName;

                                    // add delete button to object
                                    var imgDelete = document.createElement("img");
                                    imgDelete.setAttribute('class', "deleteButton");
                                    imgDelete.setAttribute('src', document.getElementById('del_no_focus_url').value);
                                    imgDelete.setAttribute('title', 'delete this file');
                                    imgDelete.setAttribute('draggable', 'false');
                                    imgDelete.setAttribute('onmouseover', 'this.src=\'' + document.getElementById('del_focus_url').value + '\'');
                                    imgDelete.setAttribute('onmouseout',  'this.src=\'' + document.getElementById('del_no_focus_url').value + '\'');
                                    imgDelete.setAttribute('onclick', "btnRemoveDragAndDropObject(" + commandConstructor.name + ", this);");
                                    newObject.insertBefore(imgDelete, newObject.firstChild);
                                    
                                    // add the new object to the input field of the droppable
                                    divs[j].innerHTML += newObject.outerHTML;
                                    // add dependency (when dragged it will add it there to, everytime table is refreshed all dependencies as removed
                                    if(fileWasAOutputFromAProcess){
                                        var dependency = new Dependency();
                                        var divTargetProcessId  = processParameterValue.process_id;
                                        var divDraggedProcessId = outputProcessId;
                                        dependency.set(divTargetProcessId, divDraggedProcessId, 0);// uses level == 0, does not meen anything
                                        commandConstructor.addDependency(dependency);
                                    }
                                }
                                else{
                                    // the file does not exist anymore(as a fileoutput that has been removed), don't add the fileoutput
                                    //alert('could not find the file with processParameterValue');
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}

/** createTableRows will create and return the HTML for the commandConstructors processes (each process will create one row).
 * @returns {string} html containing table rows
 */
function createTableRows(commandConstructor){
    var html = '';
    var addDraggedFiles = true;
    for( var i = 0; i < commandConstructor.processes.process.length ; i++){ // each process gets a row in the table
        html += createTableRow(commandConstructor, commandConstructor.processes.process[i].id, addDraggedFiles);
    }
    return html;
}

/** createTableRow will create a HTML row for given processId and return it as a string. 
 * If parameter addDraggedFiles is true it will set the output id to the value the processparametervalue have.
 * @returns {string} html containing table row
 */
function createTableRow(commandConstructor, processId, addDraggedFiles){
    var p = commandConstructor.processes.get(processId);

    // split the parameters in two different groups, inputParameters, outputParameters
    var processParameterValues = commandConstructor.processparametervalues.getWithProcessId(p.id);
    
    var inputObjects  = '';
    var outputObjects = '';
    
    // order the processParameterValues in 2 groups, inputs, outputs
    for(var i = 0; i < processParameterValues.processparametervalue.length; i++){
        var ppv           = processParameterValues.processparametervalue[i];
        var parameter     = commandConstructor.parameters.get(ppv.parameter_id);
        var parameterType = commandConstructor.parametertypes.get(parameter.parameter_type_id);
        switch(parameterType.iname){
            case 'input':
                inputObjects  += createInputProcessParameterValueObject(commandConstructor, ppv, addDraggedFiles);
                break;
            case 'output':
                outputObjects += createOutputProcessParameterValueObject(commandConstructor, ppv, addDraggedFiles);
                break;
            default:
                // otherObjects
        }
    }
    
    // each row of data will have a div around its process/inputs/outputs which which will have id of processYYY, inputsYYY, outputsYYY
    // create that id
    var rowId = createUniqueId('processes').replace("processes", "");
    
    // create a delete button/image
    var btnDeleteRow = "<img class=\"deleteRowButton\"\
                             src=" + document.getElementById('del_no_focus_url').value + " \
                             draggable=\"false\" \
                             onmouseover=\"this.src='" + document.getElementById('del_focus_url').value    + "';highlightClosestParentOfType(this, 'tr')\" \
                             onmouseout=\"this.src='"  + document.getElementById('del_no_focus_url').value + "';unhighlightClosestParentOfType(this, 'tr')\" \
                             onclick=\"btnRemoveProcess(" + commandConstructor.name + ", this, \'" + p.id + "\' )\"\
                             title=\"Delete command\"\
                             />";

    // processes will always be singular but to follow a pattern it has name of pluralis
    return  '<tr >\
                <td><div id="processes'   + rowId +'">' + createProcessObject(commandConstructor, p) + '</div></td>\
                <td><div id="inputs'      + rowId +'">' + inputObjects                               + '</div></td>\
                <td><div class="divInsideTdForRelativeToWork"><div id="outputs'     + rowId +'">' + outputObjects                              + '</div>' + btnDeleteRow + '</div></td>\
            </tr>';
}

/** createProcessObject creates the html for a given process to be inserted in the first column of the drag and drop table (command column) 
 * @returns {string} html describing a process object
 */
function createProcessObject(commandConstructor, process){
    var uniqueIdProcess = createUniqueId('hiProcessId');
    var name = process.iname && process.iname != '' ? process.iname : 'NONAME';
    var liProcessNameId = 'liProcessNameId' + uniqueIdProcess.replace('hiProcessId', "");

    return '<input type="hidden" id="' + uniqueIdProcess + '" value="' + process.id + '" />\
                <ul>\
                    <li id="' + liProcessNameId + '">' + name +  '</li>\
                    <li>'
                       + '<button id="btnShowParametersForProcess' + process.id + '" onclick="showParameterDialog('       + commandConstructor.name + ',\'' + process.id + '\')">Parameters</button>\
                    </li>\
                </ul>';
}

/** createInputProcessParameterValueObject creates the html for a input to be inserted in the second column of the drag and drop table (inputs column) 
 * @returns {string} html describing a process input object (enclosed by a div element)
 */
function createInputProcessParameterValueObject(commandConstructor, processParameterValue, addDraggedFiles){
    var uniqueIdTarget                  = createUniqueId('target');
    var uniqueIdAllowedFileType         = uniqueIdTarget.replace("target", "allowedFiletype");
    var uniqueIdProcessParameterValueId = createUniqueId('processParameterValueInputId');
    
    var parameter     = commandConstructor.parameters.get(     processParameterValue.parameter_id );
    var parameterType = commandConstructor.parametertypes.get( parameter.parameter_type_id);
    var filetype      = commandConstructor.filetypes.get(      parameterType.file_type_id );
    var extension     = filetype.extension;

    return '\
<div id="' + uniqueIdTarget + '" class="droppable" ondragover="dragOver(event)" ondrop="drop(event, ' + commandConstructor.name + ')">\
    <input type="hidden" id="' + uniqueIdAllowedFileType + '" value="' + filetype.id + '" />\
    <input type="hidden" id="' + uniqueIdProcessParameterValueId   + '" value="' + processParameterValue.id + '" />\
    <div class="processDescription" onclick="showFiles(' + commandConstructor.name + ', \'' + filetype.id + '\')">\
        <table style="border: 1px solid black;">\
            <thead>\
                <tr>\
                    <th>Description</th>\
                    <th>Type</th>\
                </tr>\
            </thead>\
            <tbody>\
                <tr>\
                    <td>' + parameter.description + '</td>\
                    <td>' + filetype.iname + '</td>\
                </tr>\
            </tbody>\
        </table>\
    </div>\
</div>';
/*
        <ul style="border: 1px solid black;">\
            <li><span style="font-weight: bold;">Type:</span> ' + filetype.iname  + '(' +  extension + ')</li>\
            <li><span style="font-weight: bold;">Description:</span> ' + parameter.description + '</li>\
        </ul>\


        <table style="border: 1px solid black;">\
            <thead>\
                <tr>\
                    <th>Name</th>\
                    <th>Description</th>\
                    <th>Extension</th>\
                </tr>\
            </thead>\
            <tbody>\
                <tr>\
                    <td>' + parameter.iname       + '</td>\
                    <td>' + parameter.description + '</td>\
                    <td>' + extension             + '</td>\
                </tr>\
            </tbody>\
        </table>\
*/
}

/** createOutputProcessParameterValueObject creates the html for a output to be inserted in the third column of the drag and drop table (outputs column)
 * @returns {string} html describing a process output object (enclosed by a div element) 
 */
function createOutputProcessParameterValueObject(commandConstructor, processParameterValue, addDraggedFiles){
    var uniqueIdDiv                     = createUniqueId('div');
    var uniqueIdFileType                = createUniqueId('fileType');
    var uniqueIdProcessParameterValueId = createUniqueId('processParameterValueOutputId');

    //var process_id    = processParameterValue.process_id;
    var parameter     = commandConstructor.parameters.get(     processParameterValue.parameter_id );
    var parameterType = commandConstructor.parametertypes.get( parameter.parameter_type_id);
    var filetype      = commandConstructor.filetypes.get(      parameterType.file_type_id );
    var extension     = filetype.extension;
    
    var uniqueIdFileId   = createUniqueId('fileIdProcessOutput');
    if(addDraggedFiles){
        // if add dragged files is called it should only be called if the file id already exist in the processParameterValue.value so we insert it as the uniqueIdFileId
        // obs because this could cause a collision (if same rand was created in the table by chanse before) this should not be allowed if the table already has
        // any values
        if( processParameterValue.value.replace("NEWFILE", "") != ''){
            uniqueIdFileId = 'fileIdProcessOutput' + processParameterValue.value.replace("NEWFILE", "");
        }
    }
    
    var fileId = uniqueIdFileId.replace('fileIdProcessOutput', "");
    return '<div id="' + uniqueIdDiv + '" draggable="false" ondragstart="dragStart(event, ' + commandConstructor.name + ')" ondragend="dragEnd(event, ' + commandConstructor.name + ')" class="permanent">\
                <input type="hidden" id="' + uniqueIdFileType + '" value="' + filetype.id + '" />\
                <input type="hidden" id="' + uniqueIdFileId   + '" value="' + fileId + '" />\
                <input type="hidden" id="' + uniqueIdProcessParameterValueId   + '" value="' + processParameterValue.id + '" />\
                <table>\
                    <thead>\
                        <tr>\
                            <th>Description</th>\
                            <th>Type</th>\
                            <th title="random number">Id</th>\
                        </tr>\
                    </thead>\
                    <tbody>\
                        <tr>\
                            <td>' + parameter.description + '</td>\
                            <td>' + filetype.iname  + '</td>\
                            <td title="random number">' + fileId + '</td>\
                        </tr>\
                    </tbody>\
                </table>\
            </div>';
}

/**
 * @class Command describes a bash command
 * @property {numeric} id id is the autoincrement for the command table
 * @property {string} iname iname is the name of the command
 * @property {string} description description is the description of the command
 * @property {numeric} software_id software_id is a foreign key to the Software class
 */
function Command() {
    this.id;
    this.iname;
    this.description;
    this.software_id;
    /** set sets the commands properties */
    this.set = function(id, iname, description, software_id){
        this.id = id;
        this.iname = iname;
        this.description = description;
        this.software_id = software_id;
    }
}
/**
 * @class Commands is a collection class for Command
 * @property {Command[]} command command is an array of Command objects
 **/
function Commands() {
    this.command = [];
    /** add adds a command to the command array
     * @param {Command} command 
     */
    this.add = function(command){
        this.command.push(command);
    }
    /** get returns the first command in the command array with given command_id
     * @param {numeric} command_id command_id is foreign key to the class Command
     * @returns {Command|undefined} 
     */
    this.get = function(command_id){
        for (var i = 0; i < this.command.length; i++){
            if(this.command[i].id == command_id){
                return this.command[i];
            }
        }
        return;
    }
}

/**
 * @class Commandline describes the execution command that a process have
 * @property {numeric} step step is a counter for the step number, starts from 0
 * @property {numeric} process_id process_id is a foreign key to the Process class
 * @property {string} command command is the actual string representation of the command
 */
function Commandline(){
    this.step;
    this.process_id;
    this.command;
    /** set sets the commandline objects values
     * @param {numeric} step
     * @param {numeric} process_id
     * @param {string} command 
     */
    this.set = function(step, process_id, command){
        this.step = step;
        this.process_id = process_id;
        this.command = command;
    }
}
/**
 * @class Commandlines is a collection class for Commandline
 * @property {Commandline[]} commandline commandline is an array of Commandline objects
 */
function Commandlines(){
   this.commandline = [];
    /** add adds a commandline to the commandline array
     * @param {Commandline} commandline 
     */
    this.add = function(commandline){
        this.commandline.push(commandline);
    }
    /** getCommandWithProcessId returns the first commandline in the commandline array with given processId
     * @param {numeric} processId processId is foreign key to the class Process
     * @returns {string} command
     */
    this.getCommandWithProcessId =  function(processId){
        for(var i = 0; i < this.commandline.length; i++){
            if(this.commandline[i].process_id == processId){
                return this.commandline[i].command;
            }
        }
    }
    /** getCommands returns HTML of all commandlines commands in a ordered list
     * @returns {string} all commandlines commands in a HTML ordered list 
     */
    this.getCommands = function(){
        var commands = [];
        for(var i = 0; i < this.commandline.length; i++){
            commands.push( this.commandline[i].command );
        }
        return "<ol><li>" + commands.join('</li><li>') + "</li></ol>";
    }
}

/**
 * @class Dependency describes a process dependency which is a relation betweene two processes
 * @property {numeric} process_id process_id is a foreign key to the Process class
 * @property {numeric} parent_process_id parent_process_id is a foreign key to the Process class
 * @property {numeric} level level is the level the relation had when retrieved with sql from the database, it is not important when storing new dependencies (not used) and it does not exist in the database table
 */
function Dependency() {
    this.process_id;
    this.parent_process_id;
    this.level;
    /** set sets the dependency properties */
    this.set = function(process_id, parent_process_id, level){
        this.process_id = process_id;
        this.parent_process_id = parent_process_id;
        this.level = level;
    }
    /** toJson returns a JSON representation of the object
     * @returns {JSON} 
     */
    this.toJson = function(){
        var tmp = new Object();
        tmp.process_id        = this.process_id.toString();
        tmp.parent_process_id = this.parent_process_id.toString();
        return tmp;        
    }
    /** toJsonForGraphviz returns a JSON representation of the object but replaces the process_id 
     * and parent_process_id with from and to which is used in the graphviz tool. Graphviz is a graph creating tool 
     * that is used to get a representation of the commands and its dependencies, the dependencies will be the edges in the graph.
     * @returns {JSON}
     */
    this.toJsonForGraphviz = function(){
        var tmp   = new Object();
        tmp.from  = this.process_id.toString();
        tmp.to    = this.parent_process_id.toString();
        return tmp;   
    }
}

/**
 * @class Dependencies is a collection class for Dependency
 * @property {Dependency[]} dependency dependency is an array of Dependency objects
 */
function Dependencies() {
    this.dependency = [];
    
    /** add adds a dependency to the dependency array
     * @param {Dependency} dependency
     */
    this.add = function(dependency){
        this.dependency.push(dependency);
    }

    /** remove removes a dependency from the dependency array
     * @param {Dependency} dependency 
     */
    this.remove = function(dependency){
        // get index of value
        var index = -1;
        for(var i = 0; i < this.dependency.length; i++){
            if( this.dependency[i].process_id == dependency.process_id && this.dependency[i].parent_process_id == dependency.parent_process_id ){
                index = i;
                break;
            }
        }
        // remove the processparametervalue
        if(index > -1){
            this.dependency.splice(index,1);
        }
    }

    /** get returns all dependencies in the dependency array with given processId
     * @param {numeric} processId processId is the foreign key to the class Process
     * @returns {Dependency[]}
     */
    this.get = function(processId){
        var dependencies = new Dependencies();
        for (var i = 0; i < this.dependency.length; i++){
            if (this.dependency[i].process_id == processId){
                dependencies.add(this.dependency[i]);
            }
        }
        return dependencies;
    }

    /** getProcessIds returns all process_ids that exist in the dependency array, it will not remove duplicates
     * @returns {string[]} of process_ids
     */
    this.getProcessIds = function(){
        var processIds = [];
        for (var i = 0; i < this.dependency.length; i++){
            processIds.push(this.dependency[i].process_id);
        }
        return processIds;
    }

    /** getWithProcessIdAndParentId returns first dependency that has the process_id == processId and parent_process_id = parentId
     * @returns {Dependency|undefined} 
     */
    this.getWithProcessIdAndParentId = function(processId, parentId){
        for (var i = 0; i < this.dependency.length; i++){
            if (this.dependency[i].process_id == processId && this.dependency[i].parent_process_id == parentId){
                return this.dependency[i];
            }
        }
    }

    /** get_all_with_process_id returns all dependencies a process has (not recursive)
     * @returns {Dependencies} 
     */
    this.get_all_with_process_id = function(process_id){// returns all dependencies a process has (not recursive)
        var dependencies = new Dependencies();
        for (var i = 0; i < this.dependency.length; i++){
            if (this.dependency[i].process_id == process_id){
                dependencies.add(this.dependency[i]);
            }
        }
        return dependencies;
    }

    /** get_all_with_process_id_recursivly returns all dependencies a process has (recursive)
     * @returns {Dependencies} 
     */
    this.get_all_with_process_id_recursivly = function(process_id){// returns all dependencies a process has
        var dependencies = new Dependencies();
        for (var i = 0; i < this.dependency.length; i++){
            if (this.dependency[i].process_id == process_id){
                dependencies.add(this.dependency[i]);
                var dependencies2 = this.get_all_with_process_id_recursivly(this.dependency[i].parent_process_id);
                for (var j = 0; j < dependencies2.dependency.length; j++){
                    dependencies.add(dependencies2.dependency[j]);
                }
            }
        }
        return dependencies;
    }

    /** toJson returns a JSON representation of all dependenciy objects
     * @returns {JSON} 
     */
    this.toJson = function(){
        var d = [];
        for (var i = 0; i < this.dependency.length; i++){  // for each parameter
            d.push( this.dependency[i].toJson() );
        }
        return d;
    }

    /** toJsonForGraphviz returns a JSON representation of the object but replaces the process_id 
     * and parent_process_id with from and to which is used in the graphviz tool. Graphviz is a graph creating tool 
     * that is used to get a representation of the commands and its dependencies, the dependencies will be the edges in the graph.
     * @returns {JSON} 
     */
    this.toJsonForGraphviz = function(){
        var jsonObjects = [];
        for (var i = 0; i < this.dependency.length; i++){
            jsonObjects.push( this.dependency[i].toJsonForGraphviz() );
        }
        return jsonObjects;
    }
}

/**
 * @class Filetype describes what type a file is.
 * Filetypes are built upon hierarchy to make it simpler when it comes to defining acceptable files in a inputbox for a command.
 * Example: You have two input boxes where one accept only a sorted BAM file and the other accept all BAM files (sorted or unsorted).
 * To avoid the need to say that one input box only accept a file with filetype BAM and the other accepts filetypes of BAM or a SORTEDBAM you make a relation betweene the two.
 * The relation is: a 'sorted bam file' is a 'bam file' or the father of the 'sorted bam file' is the 'bam file'
 * If you have the relation you can say that the first input box accepts a 'sorted bam file' type and the other a 'bam file'.
 * When you then check if it is possible to add a file to the input you check if the input accepts the filetype the file has or if any of the files parent types is accepted in the input.
 * @property {numeric} id id is the autoincrement for the filetype table
 * @property {string} iname iname is the name of the filetype
 * @property {string} extension extension is the extension of the filetype
 * @property {numeric} parent_file_type_id parent_file_type_id is the parent file type for this filetype. 
 */
function Filetype() {
    this.id;
    this.iname;
    this.extension;
    this.parent_file_type_id;
    /** set sets the filetype properties */
    this.set = function(id, iname, extension, parent_file_type_id){
        this.id = id;
        this.iname = iname;
        this.extension = extension;
        this.parent_file_type_id = parent_file_type_id;
    }
}
/**
 * @class Filetypes is a collection class for Filetype
 * @property {Filetype[]} filetype filetype is an array of Filetype objects
 */
function Filetypes() {
    this.filetype = [];

    /** add adds a filetype to the filetype array
     * @param {Filetype} filetype 
     */
    this.add = function(filetype){
        this.filetype.push(filetype);
    }

    /** get return first filetype (should be only one) in the filetype array with given filetypeId
     * @param {numeric} filetypeId filetypeId is the foreign key to the class Filetype
     * @returns {Filetype|undefined} 
     */
    this.get = function(filetypeId){
        for (var i = 0; i < this.filetype.length; i++){
            if(this.filetype[i].id == filetypeId){
                return this.filetype[i];
            }
        }
    }

    /** get_all_with_filetype_id_recursivly return a filetype and all its supertypes (i.e. the type and its supertypes (opposite of subtypes))
     * @param {numeric} filetypeId filetypeId is the foreign key to the class Filetype
     * @returns {Filetypes} 
     */
    this.get_all_with_filetype_id_recursivly = function(filetype_id){// returns all filetypes a filetype is (recursively)
        var filetypes = new Filetypes();
        for (var i = 0; i < this.filetype.length; i++){
            if (this.filetype[i].id == filetype_id){
                filetypes.add(this.filetype[i]);
                var filetypes2 = this.get_all_with_filetype_id_recursivly(this.filetype[i].parent_file_type_id);
                for (var j = 0; j < filetypes2.filetype.length; j++){
                    filetypes.add(filetypes2.filetype[j]);
                }
            }
        }
        return filetypes;
    }

    /** exists returns true if given id exist in the filetypes array false otherwise
     * @param {filetypeId} filetypeId filetypeId is the foreign key to the class Filetype
     * @returns {boolean} true if exist false otherwise 
     */
    this.exists = function(filetypeId){
        for (var i = 0; i < this.filetype.length; i++){
            if (this.filetype[i].id == filetypeId){
                return true;
            }
        }
        return false;
    }
}

/**
 * @class Parameter describes a parameter for a command, all parts in a command is a parameter
 * @property {numeric} id id is the autoincrement for the parameter table
 * @property {string} iname iname is the name of the parameter
 * @property {string} description description is the description of the parameter
 * @property {string} template template is the template toolkit template string of the parameter
 * @property {boolean} is_mandatory is_mandatory is true it the parameter is mandatory
 * @property {numeric} locus locus is the position nr the parameter has amongs the parameters (different parameters may have the same locus but when creating the command it is ordered on locus)
 * @property {numeric} min_items min_items with the max_items describes the number of inputs or outputs the parameter has or must have
 * @property {numeric} max_items max_items with the min_items describes the number of inputs or outputs the parameter has or must have
 * @property {numeric} parameter_type_id parameter_type_id is a foreign key to the parametertype class and describes the type of the parameter
 * @property {numeric} command_id command_id is a foreign key to the command class and tells what command this parameter belongs to
 */
function Parameter() {
    this.id;
    this.iname;
    this.description;
    this.template;
    this.is_mandatory;
    this.locus;
    this.min_items;
    this.max_items;
    this.parameter_type_id;
    this.command_id;
    /** set sets the parameter properties */
    this.set = function(id, iname, description, template, is_mandatory, locus, min_items, max_items, parameter_type_id, command_id){
        this.id = id;
        this.iname = iname;
        this.description = description;
        this.template = template;
        this.is_mandatory = is_mandatory;
        this.locus = locus;
        this.min_items = min_items;
        this.max_items = max_items;
        this.parameter_type_id = parameter_type_id;
        this.command_id = command_id;
    }
    /** getMinNumberItems returns the min number of items the parameter must have
     * @returns {numeric} a non negative numeric 
     */
    this.getMinNumberItems = function(){
        if(this.min_items == 0 && this.max_items == 0){// none allowed
            return 0;
        }
        else if ( this.min_items > this.max_items){    // infinite number, return min_items
            return this.min_items;
        }
        else if (this.max_items == this.min_items ){   // exact number of parameters
            return this.min_items
        }
        else {                                         // range
            return this.min_items;
        }
    }
}

/** helper class to be able to sort out duplicates from a array 
 * @returns {string[]} array with strings with unique values 
 */
Array.prototype.getUnique = function(){
   var u = {}, a = [];
   for(var i = 0, l = this.length; i < l; ++i){
      if(this[i] in u)
         continue;
      a.push(this[i]);
      u[this[i]] = 1;
   }
   return a;
}

/**
 * @class Parameters is a collection class for Parameter
 * @property {Parameter[]} parameter parameter is an array of Parameter objects
 */
function Parameters() {
    this.parameter = [];

    /** add adds a parameter to the parameter array
     * @param {Parameter} parameter 
     */
    this.add = function(parameter){
        this.parameter.push(parameter);
    }

    /** get return first parameter (should be only one) in the parameter array with given parameter_id
     * @param {numeric} parameter_id parameter_id is the foreign key to the class Parameter
     * @returns {Parameter|undefined} 
     */
    this.get = function(parameter_id){
        for (var i = 0; i < this.parameter.length; i++){
            if(this.parameter[i].id == parameter_id){
                return this.parameter[i];
            }
        }
        return;
    }

    /** getWithIds return a Parameters object with all parameters that has any one of the parameter_id in the parameter_ids array. 
     * To avoid duplicates the array with parameter_ids is removed of all duplicates.
     * @param {string[]} parameter_ids parameter_ids is an array of foreign keys to the class Parameter
     * @returns {Parameters} 
     */
    this.getWithIds = function(parameter_ids){
        var parameter_ids2 = parameter_ids.getUnique();
        var p = new Parameters();
        for (var i = 0; i < parameter_ids2.length; i++){
            for(var j= 0; j < this.parameter.length; j++){
                if(parameter_ids2		[i] == this.parameter[j].id){
                    p.add(this.parameter[j]);
                }
            }
        }
        return p;
    }
    
    /** getWithCommandId returns all Parameters with given command_id in a Parameters object.
     * @param {numeric} command_id command_id is an foreign key to the class Command
     * @returns {Parameters} 
     */
    this.getWithCommandId = function(command_id){
        var p = new Parameters();
        for (var i = 0; i < this.parameter.length; i++){
            if(this.parameter[i].command_id == command_id){
                p.add(this.parameter[i]);
            }
        }
        return p;
    }

    /** compareLocus is a compare function used when sorting Parameter objects with the sort command.
     * @param {a} a a is the first parameter that is going to be compared
     * @param {b} b b is the second parameter that is going to be compared
     * @returns {numeric} -1, 0 or 1 depending on a and b's locus 
     */
    this.compareLocus = function(a,b){
        if (a.locus < b.locus)
            return -1;
        if (a.locus > b.locus)
            return 1;
        return 0;
    }
}

/**
 * @class Parametertype describes what type a parameter is
 * @property {numeric} id id is the autoincrement for the parametertype table
 * @property {string} iname iname is the name of the parametertype
 * @property {string} description description is the description of the parametertype
 * @property {numeric} file_type_id file_type_id is a foreign key to the filetype class and tells what filetype this parametertype has
 */
function Parametertype() {
    this.id;
    this.iname;
    this.description;
    this.file_type_id;
    /** set sets the parametertype properties */
    this.set = function(id, iname, description, file_type_id){
        this.id = id;
        this.iname = iname;
        this.description = description;
        this.file_type_id = file_type_id;
    }
}
/**
 * @class Parametertypes is a collection class for Parametertype
 * @property {Parametertype[]} parametertype parametertype is an array of Parametertype objects
 */
function Parametertypes() {
    this.parametertype = [];
    /** add adds a parametertype to the parametertype array
     * @param {Parametertype} parametertype 
     */
    this.add = function(parametertype){
        this.parametertype.push(parametertype);
    }
    /** get return first parametertype (should be only one) in the parametertype array with given parametertypeId
     * @param {numeric} parametertypeId parametertypeId is the foreign key to the class Parametertype
     * @returns {Parametertype|undefined} 
     */
    this.get = function(parametertypeId){
        for (var i = 0; i < this.parametertype.length; i++){
            if(this.parametertype[i].id == parametertypeId){
                return this.parametertype[i];
            }
        }
    }
}
/**
 * @class Process describes a step in a template execution
 * @property {numeric} id id is the autoincrement for the process table
 * @property {string} iname iname is the name of the process
 * @property {string} description description is the description of the process
 * @property {numeric} command_id command_id is a foreign key to the Command class and tells what command this process has
 * @property {numeric} project_id project_id is a foreign key to the Project class and tells in which project this process was created
 * @property {numeric} person_id person_id is a foreign key to the Person class and tells which person this process was created by
 * @property {numeric} type type is a numeric that describes what type the process is. It could be 1 == fake/template, 2 == injob/waiting to be executed and 3 == done.
 */
function Process() {
    this.id;
    this.iname;
    this.description;
    this.command_id;
    this.project_id;
    this.person_id;
    this.type;
    /** set sets the process properties */
    this.set = function(id, iname, description, command_id, project_id, person_id, type){
        this.id = id;
        this.iname = iname;
        this.description = description;
        this.command_id = command_id;
        this.project_id = project_id;
        this.person_id = person_id;
        this.type = type;
    }
    
    /** toJson returns a JSON representation of the object
     * @returns {JSON} 
     */
    this.toJson = function(){
        var tmp = new Object();
        tmp.id          = this.id.toString();
        tmp.iname       = this.iname.toString();
        tmp.description = this.description.toString();
        tmp.command_id  = this.command_id.toString();
        tmp.project_id  = this.project_id.toString();
        tmp.person_id   = this.person_id.toString();
        tmp.type        = this.type.toString();                
        return tmp;        
    }
    /** toJsonForGraphviz returns a JSON representation of the object but replaces the id and iname
     * with name and label which is used in the graphviz tool. Graphviz is a graph creating tool 
     * that is used to get a representation of the commands and its dependencies, the processes will be the nodes in the graph
     * @returns {JSON} 
     */
    this.toJsonForGraphviz = function(){
        var tmp   = new Object();
        tmp.name  = this.id.toString();      // in graphviz the name value is the unique id and label is for the text shown in the graph
        tmp.label = this.iname.toString();
        return tmp;   
    }
}
/**
 * @class Processes is a collection class for Processes
 * @property {Process[]} process process is an array of Process objects
 */
function Processes() {
    this.process = [];
    /** add adds a process to the process array
     * @param {Process} process 
     */
    this.add = function(process){
        this.process.push(process);
    }

    /** remove removes a process from the process array
     * @param {Process} process 
     */
    this.remove = function(process){
        // get index of value
        var index = -1;
        for(var i = 0; i < this.process.length; i++){
            if( this.process[i].id == process.id ){
                index = i;
                break;
            }
        }
        // remove the processparametervalue
        if(index > -1){
            this.process.splice(index,1);
        }
    }

    /** exists returns true if a process in the process array has the same id as the given id otherwise it will return false
     * @param {processId} id id is the foreign key to the class Process
     * @returns {boolean} true if exist false otherwise 
     */
    this.exists = function(id){
        for (var i = 0; i < this.process.length; i++){
            if (this.process[i].id == id){
                return true;
            }
        }
        return false;
    }
    /** get return first process (should be only one) in the process array with given process_id
     * @param {numeric} process_id process_id is the foreign key to the class Process
     * @returns {Process|undefined} 
     */
    this.get = function(process_id){
        for (var i = 0; i < this.process.length; i++){
            if (this.process[i].id == process_id){
                return this.process[i];
            }
        }
    }
    
    /** toJsonForGraphviz returns a JSON representation of the object but replaces the id with name
     * and iname with label which is used in the graphviz tool to describe a nodes id and label. Graphviz is a graph creating tool 
     * that is used to get a representation of the commands and its dependencies, the dependencies will be the edges in the graph.
     * @returns {JSON} 
     */
    this.toJsonForGraphviz = function(){
        var processesInJson = [];
        for (var i = 0; i < this.process.length; i++){
            processesInJson.push( this.process[i].toJsonForGraphviz() );
        }
        return processesInJson;
    }
}
/**
 * @class Processparametervalue describes the value(s) a parameter has in a process
 * @property {numeric} id id is the autoincrement for the processparametervalue table
 * @property {numeric} process_id process_id is a foreign key to the Process class and tells what process this processparametervalue is associated with
 * @property {numeric} parameter_id parameter_id is a foreign key to the Parameter class and tells what parameter this processparametervalue is associated with
 * @property {string} value value is the value this processparametervalue has
 * @property {numeric} locus locus is the position this processaparametervalue has in relation to other processparametervalues for this parameter
 */
function Processparametervalue() {
    this.id;
    this.process_id;
    this.parameter_id;
    this.value;
    this.locus;
    
    /** set sets the parameter properties */
    this.set = function(id, process_id, parameter_id, value, locus){
        this.id = id;
        this.process_id = process_id;
        this.parameter_id = parameter_id;
        this.value = value;
        this.locus = locus;
    }
}
/**
 * @class Processesparametervalues is a collection class for Processparametervalue
 * @property {Processparametervalue[]} processparametervalue processparametervalue is an array of Processparametervalue objects
 */
function Processparametervalues() {
    this.processparametervalue = [];
    /** add adds a processparametervalue to the processparametervalue array
     * @param {Processparametervalue} processparametervalue 
     */
    this.add = function(processparametervalue){
        this.processparametervalue.push(processparametervalue);
    }
    /** get return first processparametervalue (should be only one) in the processparametervalue array with given processparametervalue_id
     * @param {numeric} processparametervalue_id processparametervalue_id is the foreign key to the class Processparametervalue
     * @returns {Processparametervalue|undefined} 
     */
    this.get = function(processparametervalue_id){
        for (var i = 0; i < this.processparametervalue.length; i++){
            if (this.processparametervalue[i].id == processparametervalue_id){
                return this.processparametervalue[i];
            }
        }
    }

    /** remove removes a Processparametervalue from the processparametervalue array
     * @param {Processparametervalue} processParameterValue 
     */
    this.remove = function(processParameterValue){
        // get index of value
        var index = -1;
        for(var i = 0; i < this.processparametervalue.length; i++){
            if( this.processparametervalue[i].id == processParameterValue.id ){
                index = i;
                break;
            }
        }
        // remove the processparametervalue
        if(index > -1){        
            this.processparametervalue.splice(index,1);
        }
    }

    /** getWithProcessId returns all Processparametervalues from the processparametervalue array which has the id of processId
     * @returns {Processparametervalues} 
     */
    this.getWithProcessId = function(processId){
        var p = new Processparametervalues();
        for (var i = 0; i < this.processparametervalue.length; i++){
            if(this.processparametervalue[i].process_id == processId){
                p.add(this.processparametervalue[i]);
            }
        }
        return p;
    }
    
    /** getParamterIds returns all parameter_ids that exist in the parameter array
     * @returns {string[]} of parameter_ids
     */
    this.getParameterIds = function(){
        var parameterIds = [];
        for (var i = 0; i < this.processparametervalue.length; i++){
            if(parameterIds.indexOf(this.processparametervalue[i].parameter_id) == -1){// only unique ones
                parameterIds.push(this.processparametervalue[i].parameter_id);
            }
        }
        return parameterIds;
    }
    /** getWithParameterId returns all Processparametervalues from the processparametervalue array which has the parameter_id of parameterId
     * @returns {Processparametervalues} 
     */
    this.getWithParameterId = function(parameterId){
        var p = new Processparametervalues();
        for (var i = 0; i < this.processparametervalue.length; i++){
            if(this.processparametervalue[i].parameter_id == parameterId){
                p.add(this.processparametervalue[i]);
            }
        }
        return p;
    }
    /** getWithProcessId returns all Processparametervalues from the processparametervalue array which has both the id of processId and he parameter_id of parameterId
     * @returns {Processparametervalues}
     */
    this.getWithProcessIdAndParameterId = function(processId, parameterId){
        var p = new Processparametervalues();
        for (var i = 0; i < this.processparametervalue.length; i++){
            if(this.processparametervalue[i].process_id == processId && this.processparametervalue[i].parameter_id == parameterId){
                p.add(this.processparametervalue[i]);
            }
        }
        return p;
    }
    /** getMaxLocus return the max locus of all the processparametervalues that exist in the processparametervalue array.
     * @returns [''|numeric] It returns '' if no values exist otherwise the max value of the locus.
     */
    this.getMaxLocus =  function(){
        var maxLocus = this.processparametervalue.length > 0 ? 0 : ''; // set the default max to 0 if there exist any values, if there is only one value then it will get the
                                                                       // largest value, if none exist '' is going to be returned
        for (var i = 0; i < this.processparametervalue.length; i++){
            if(this.processparametervalue[i].locus >= maxLocus){
                maxLocus = this.processparametervalue[i].locus;
            }
        }
        return maxLocus;
    }

    /** compareLocus is a compare function used when sorting Processparametervalue objects with the sort command.
     * @param {a} a a is the first parameter that is going to be compared
     * @param {b} b b is the second parameter that is going to be compared
     * @returns {numeric} -1, 0 or 1 depending on a and b's locus 
     */
    this.compareLocus = function(a,b){
        if (a.locus < b.locus)
            return -1;
        if (a.locus > b.locus)
            return 1;
        return 0;
    }
}
/**
 * @class Software describes a software that could be used when executing a command
 * @property {numeric} id id is the autoincrement for the software table
 * @property {string} iname iname is the name of the software
 * @property {string} version version is the version of the software
 */
function Software() {
    this.id;
    this.iname;
    this.version;
    /** set sets the parameter properties */
    this.set = function(id, iname, version){
        this.id = id;
        this.iname = iname;
        this.version = version;
    }
}
/**
 * @class Softwares is a collection class for Software
 * @property {Software[]} software software is an array of Software objects
 */
function Softwares() {
    this.software = [];
    /** add adds a software to the software array
     * @param {Software} software 
     */
    this.add = function(software){
        this.software.push(software);
    }
    /** get return first software (should be only one) in the software array with given software_id
     * @param {numeric} software_id software_id is the foreign key to the class Software
     * @returns {Software|undefined} 
     */
    this.get = function(software_id){
        for (var i = 0; i < this.software.length; i++){
            if (this.software[i].id == software_id){
                return this.software[i];
            }
        }
    }
}
/**
 * @class Previewgraph is a class that holds functions that relates to a preview svg of the processes
 * @property {boolean} useColors useColors is set to true if colors is going to be used in the previewgraph
 * @property {boolean} addCommandsToGraph addCommandsToGraph is set to true if instead of the Process name the string representation of a process commands execution is going to be shown on the node in the previewgraph
 * @property {boolean} showNodesThatAreNotOkToRun showNodesThatAreNotOkToRun is set to true if you do not want to see the commands that have not all inputs correctly set
 * @property {object} edge edge describes the default values for the edges used in the graphviz dot graph
 * @property {object} global global describes the default values for the graph used in the graphviz dot graph
 * @property {object} graphglobal global describes the default global values for the graph used in the graphviz dot graph
 * @property {object[]} nodes nodes contains all the nodes that is passed to the graphviz dot graph
 * @property {object[]} edges edges contains all the edges that is passed to the graphviz dot graph
 * @property {object} possiblePoligonNodeShapes possiblePoligonNodeShapes is used to be able to match what graphviz shape has what svg object in the svg graph. It is mainly used when highlighting objects in the svg when a row is moused over on the drag and drop table.
*/
function Previewgraph(){
    // default features
    this.useColors                  = true;
    this.addCommandsToGraph         = false;
    this.showNodesThatAreNotOkToRun = true;
    
    // default values
    this.edge = {   "color": "black", 
                    "fontname": "'lucida grande',tahoma,verdana, sans-serif",
                    "fontsize":"10"};
                    
    this.global = { "directed": "1",
                     "name": "svg" };

    this.graph  = { "id":"svgGraph", /* mandatory, used in function below */
                    "label": "",
                    "rankdir": "TB",
                    "fontname":"'lucida grande',tahoma,verdana, sans-serif",
                    "fontsize":"14",
                    "size":"7.292,",
                    "bgcolor":"transparent" };
                    
    this.node   = { "shape": "oval", /* mandatory, used in function below */
                    "fontname": "'lucida grande',tahoma,verdana, sans-serif",
                    "fontsize":"10"};// graphviz ignores alpha values. :(, have to insert transparent fill colors for the mouseover to work
                    
    this.nodes = [];
    this.edges = [];
    
    this.possiblePoligonNodeShapes = {   'box':             {'svgComponent':'polygon'}
                                        ,'box3d':           {'svgComponent':'polygon'}
                                        ,'circle':          {'svgComponent':'ellipse'}
                                        ,'component':       {'svgComponent':'polygon'}
                                        ,'diamond':         {'svgComponent':'polygon'}
                                        ,'doublecircle':    {'svgComponent':'ellipse'}
                                        ,'doubleoctagon':   {'svgComponent':'polygon'}
                                        ,'egg':             {'svgComponent':'polygon'}
                                        ,'ellipse':         {'svgComponent':'ellipse'}
                                        ,'folder':          {'svgComponent':'polygon'}
                                        ,'hexagon':         {'svgComponent':'polygon'}
                                        ,'house':           {'svgComponent':'polygon'}
                                        ,'invhouse':        {'svgComponent':'polygon'}
                                        ,'invtrapezium':    {'svgComponent':'polygon'}
                                        ,'invtriangle':     {'svgComponent':'polygon'}
                                        ,'Mcircle':         {'svgComponent':'ellipse'}
                                        ,'Mdiamond':        {'svgComponent':'polygon'}
                                        ,'Msquare':         {'svgComponent':'polygon'}
                                        ,'none':            {'svgComponent':'a'}
                                        ,'note':            {'svgComponent':'polygon'}
                                        ,'octagon':         {'svgComponent':'polygon'}
                                        ,'oval':            {'svgComponent':'ellipse'}
                                        ,'parallelogram':   {'svgComponent':'polygon'}
                                        ,'pentagon':        {'svgComponent':'polygon'}
                                        ,'plaintext':       {'svgComponent':'a'}
                                        ,'point':           {'svgComponent':'ellipse'}
                                        ,'polygon':         {'svgComponent':'polygon'}
                                        ,'rect':            {'svgComponent':'polygon'}
                                        ,'rectangle':       {'svgComponent':'polygon'}
                                        ,'septagon':        {'svgComponent':'polygon'}
                                        ,'square':          {'svgComponent':'polygon'}
                                        ,'tab':             {'svgComponent':'polygon'}
                                        ,'trapezium':       {'svgComponent':'polygon'}
                                        ,'triangle':        {'svgComponent':'polygon'}
                                        ,'tripleoctagon':   {'svgComponent':'polygon'}
                                        };
    
    /*  {
            edge:  {"ID1":"VALUE",  "ID2":"VALUE2"},
            global:{"ID3":"VALUE3", "ID4":"VALUE4"},            
            graph: {"ID5":"VALUE5", "ID6":"VALUE6"},
            node:  {"ID7":"VALUE7", "ID8":"VALUE8"},
            nodes: {"NODEID":["ID9":"VALUE9", ], "NODEID":["ID10":"VALUE10"]}
            edges: {"EDGEID":["ID11":"VALUE11", ], "NODEID":["ID12":"VALUE12"]}
        }
    */
    /** update updates or adds new global graphviz objects parameters from the given properties.
     * @param {Software} software 
     */
    this.update = function(propertiesHash){
        for (var k in propertiesHash) {
             switch(k){
                case 'edge':
                    for( var l in propertiesHash[k]){
                        this.edge[l] = propertiesHash[k][l];
                    }
                break;
                case 'global':
                    for( var l in propertiesHash[k]){
                        this.global[l] = propertiesHash[k][l];
                    }
                break;
                case 'graph':
                    for( var l in propertiesHash[k]){
                        this.graph[l] = propertiesHash[k][l];
                    }
                break;
                case 'node':
                    for( var l in propertiesHash[k]){
                        this.node[l] = propertiesHash[k][l];
                    }
                break;
                default:
                break
            }
        }
        
    }

    /** addTransparentBlackBackgroundToAllNodes steps through the svg and updates all nodes and set
     * style to filled, the color to black and the opacity to 0 which makes it possible to later only 
     * change the opacity of the color to get a onmouseover effect.
     * addTransparentBlackBackgroundToAllNodes must be called after the svg has been created beacause
     * the perl module graphviz2 does not support alpha values of 0.
     * I tried:  graph.node = { "style":"filled", "fillcolor":"#000000aa" } to work with the transparent part (if set to white and 0 opacity the fill got none in the svg
     * and if used black with opacity the opacity was ignored 
     */
    this.addTransparentBlackBackgroundToAllNodes = function(){
        var svgGraph    = document.getElementById(this.graph['id']);// what the svg is called
        var svgNodes    = svgGraph.getElementsByTagName("g");
        for(var i = 0; i < svgNodes.length; i++) {
            var node = svgNodes[i];
            var shape = this.node['shape']; // name in graphviz
            var svgElement = this.possiblePoligonNodeShapes[shape]['svgComponent'];
            var shape = node.getElementsByTagName(svgElement);
            for(var j = 0; j < shape.length; j++) {
                shape[j].setAttribute("fill", "#000000");
                shape[j].setAttribute("fill-opacity", "0.0");
                shape[j].setAttribute("style", "filled");
            }
        }
    }

    /** addMouseEventsToSvg adds: 
     * 1. mouseover == highlight row in table row
     * 2. click     == open processProperties 
     * to the graph svg.
     */
    this.addMouseEventsToSvg = function(commandConstructor){
        var svgGraph    = document.getElementById(this.graph['id']);// what the svg is called
        var svgNodes    = svgGraph.getElementsByTagName("g");
        for(var i = 0; i < svgNodes.length; i++) {
            var node = svgNodes[i];
            if(node.getAttribute("class") == "node"){
                if(node.id.indexOf("node") < 0 ){ 
                    // a command
                    var input = getHiddenInputFromProcessId(node.id, 'tblProcesses');// gets the table's hidden input where the process is stored to be able highlight that row
                    node.setAttribute('onmouseover', commandConstructor.name+'.previewgraph.highlightSvgObjectWithId(\'' + node.id + '\');highlightClosestParentOfType('   + input.id + ', \'tr\')');
                    node.setAttribute('onmouseout',  commandConstructor.name+'.previewgraph.unhighlightSvgObjectWithId(\'' + node.id + '\');unhighlightClosestParentOfType(' + input.id + ', \'tr\')');
                    if(commandConstructor){
                        node.setAttribute('onclick',        "showParameterDialog(" + commandConstructor.name + ",'" + node.id + "')" );
                    }
                }
                else{
                    // a file output
                    // (commands have a id that is the process id, if a it is a file or fileoutput it will have id with node in it
                    // as it has not been given any id in the javascript and then graphviz creates a id which will be nodeX where X is a number)
                }
            }
        }
    }

    /** highlightSvgObjectWithId changes the fill-opacity to 0.2 on the obect, which gives a highlight effect*/
    this.highlightSvgObjectWithId = function(id){
        var obj = document.getElementById(id);
        if(obj){// if history graph is loaded you will not find any elements with that id
            var svgElement = this.possiblePoligonNodeShapes[this.node['shape']]['svgComponent'];
            var shape = obj.getElementsByTagName(svgElement);
            for(var i = 0; i < shape.length; i++) {
                shape[i].setAttribute("fill-opacity", 0.2);
            }
        }
    }

    /** unhighlightSvgObjectWithId changes the fill-opacity to 0.0 on the obect, which removes possible highlight effect on a node*/
    this.unhighlightSvgObjectWithId = function(id){
        var obj = document.getElementById(id);
        if(obj){// if history graph is loaded you will not find any elements with that id
            var svgElement = this.possiblePoligonNodeShapes[this.node['shape']]['svgComponent'];
            var shape = obj.getElementsByTagName(svgElement);
            for(var i = 0; i < shape.length; i++) {
                shape[i].setAttribute("fill-opacity", 0.0);
            }
        }  
    }

    /** createGraphFromCommandConstructor create edges and nodes for a graph but only betweene the commands, ie no files and other luxuriates will be added*/
    this.createGraphFromCommandConstructor = function(commandConstructor){
        tmp.nodes  = this.processes.toJsonForGraphviz();
        tmp.edges  = this.dependencies.toJsonForGraphviz();
    }
    
    /** showEditDialog opens a dialog for the graph that lets you edit the graph svg object, or rather
     * it shows options that after set will be passed to the server which will result in a other svg. 
     */
    this.showEditDialog = function(){
        // sort the hash values of the poligonnodesshapes, have to create a array for this to work
        var keys = [];
        for (var key in this.possiblePoligonNodeShapes) {
          if (this.possiblePoligonNodeShapes.hasOwnProperty(key)) {
            keys.push(key);
          }
        }
        keys.sort (function(a,b){return a.toLowerCase() < b.toLowerCase() ? -1 : a.toLowerCase() > b.toLowerCase() ? 1 : 0;}); // sort on everything in lowercase
        var html;
        var usesColorHTML = clientCommandConstructor.previewgraph.useColors == true ? ' checked="checked" ' : '';
        var addCommandsToGraphHTML = clientCommandConstructor.previewgraph.addCommandsToGraph == true ? ' checked="checked" ' : '';
        var showNodesThatAreNotOkHTML = clientCommandConstructor.previewgraph.showNodesThatAreNotOkToRun == true ? ' checked="checked" ' : '';
        var usedShape = this.node['shape'];
        html  = '<div id="editSvgWindow">';
        html += '<h3 class="left">Graph</h3>';
        html += '<ul>';
        html += '<li><input type="checkbox" name="inputColor"\
                            ' + usesColorHTML + '\
                            onchange="clientCommandConstructor.previewgraph.changeUseColors(clientCommandConstructor.previewgraph.useColors?false:true);\
                            clientCommandConstructor.updatePreviewGraph();" />';
        html += '<label for="inputColor">Use color</label></li>';
        html += '</ul>';
        html += '<h3 class="left">Node</h3>';
        html += '<ul>';
        html += '<li><label for="nodeShape">Shape</label>';
        html += '<select name="nodeShape" id="nodeShape" onchange="clientCommandConstructor.previewgraph.update({\'node\':{\'shape\':this.value}});clientCommandConstructor.updatePreviewGraph();">\
                         <option value="none"></option>';
                         for(var i=0; i< keys.length; i++){
                            var shape = keys[i];
                            var selected = shape == usedShape ? ' selected="selected"' : '';
                            html += '<option value="' + shape + '" ' + selected + '>' + shape + '</option>';
                         }
        html +=      '</select>';
        html += '</li>';
        html += '<li><input type="checkbox" name="addCommandsToGraph"\
                            ' + addCommandsToGraphHTML + '\
                            onchange="clientCommandConstructor.previewgraph.changeAddCommandsToGraph(clientCommandConstructor.previewgraph.addCommandsToGraph?false:true);\
                            clientCommandConstructor.updatePreviewGraph();" />';
        html += '<label for="addCommandsToGraph">Add commands to graph</label></li>';
        

        html += '<li><input type="checkbox" name="showNodesThatAreNotOkToRun"\
                            ' + showNodesThatAreNotOkHTML + '\
                            onchange="clientCommandConstructor.previewgraph.changeShowNodesThatAreNotOkToRun(clientCommandConstructor.previewgraph.showNodesThatAreNotOkToRun?false:true);\
                            clientCommandConstructor.updatePreviewGraph();" />';
        html += '<label for="showNodesThatAreNotOkToRun">Show nodes that are not ok to run</label></li>';
        html += '</ul>';
        html += '</div>';
        
        showDialog(html, 'edit graphviz object');    
    }
    
    /** createGraphFromTable steps through the drag and drop table and creates all the nodes and edges for the graph.
     * It will trim the file hash name length. It will take the min length on filenames that could describe the files
     * uniquelly within the project but will not go below 4 chars long.
     */
    this.createGraphFromTable = function(commandConstructor, tableId){
        // clear previous nodes and edges
        this.nodes = [];
        this.edges = [];
        
        // get min length of names on the file inputs
        var divFiles = document.getElementById('projectFiles');
        var inputFile  = divFiles.getElementsByTagName('input');
        var files = new Object();
        for (var f = 0; f < inputFile.length; f++ ){
            if(inputFile[f].id.indexOf("fileId") != -1){
                files[inputFile[f].value] = 1;
            }
        }
        var minFileLength = 4;  // start with fileLength of 4
        var t = 0;
        do{
            t = 0;
            var tmp = new Object();
            // initiate with value of 0
            for(var k1 in files) {    
                tmp[k1.substring(0,minFileLength)] = 0;
            }
            // add 1 to each hash value for each file beginning with that value
            for (var k in files) {    
                if (files.hasOwnProperty(k)) {
                    tmp[k.substring(0,minFileLength)] += 1;
                }
            }
             
            for (var k2 in tmp){
                if (tmp.hasOwnProperty(k2)) {
                    if(tmp[k2] > 1){// if two files have the same name, increase length to check
                        t = -1;
                        minFileLength++;
                        break;
                    }
                }
            }
        }
        while( t < 0 );
        
        var tbl = document.getElementById(tableId);
        
        // create complete graph with:
        //  commands (processes)    - as nodes
        //  dependencies            - as edges, both between commands (processes) and from files (as input) and to files (as output)
        // Ide: Create the nodes and edges in 3 steps
        //  1. go through table and create nodes from all commands and create edges for all inputs
        //  2. go through table and get all outputs and draw a edge for each output that is not used as an input (that is why we go seperate this step from last step)
        //  3. create file nodes for all files that has been used

        // Note:
        // in the graph the nodes will have the process_id as its id (in graphviz id is called name and the name shown is label)
        // all commands and files from the system is nodes but the files and output to a file has no borders
        if(tbl){
            var processInputs  = [];// store all input files
            var files          = [];// store all files used which is not a output from a process 
                                    // (div has hidden called either fileIdRAND or fileIdProcessOutputRAND which value has the id for the file)
            
            var nodes = [];
            var edges = [];
            
            // 1. create nodes for the commands (where the id is the process_id of the command) and edges for the inputs
            for (var i = 0, row; row = tbl.rows[i]; i++) {
                var rowId = getRowId(row);
                
                if( rowId != 0 ){
                    // here we have a row which is a process
                    var process = getRowProcessFromRowUniqueRowId(commandConstructor, rowId)
                    
                    // create a node from the command
                    var tmp2    = new Object();
                    tmp2.name   = process.id; // get process_id, in graphviz the name value is the unique id and label is for the text shown in the graph
                    tmp2.id     = process.id; // set the id for the svg node, this will internally (in graphviz) only be used as a prefix, it is up to the one
                                              // who insert the value to ensure they are unique, but because my process_ids are stored in a value field of a hidden
                                              // and not used as a id I can use the process id on the svg and not create a collision
                    tmp2.tooltip = process.iname;
                                            
                    // get name from li with name liProcessNameIdRAND
                    var lis = row.getElementsByTagName('li');
                    for (var l = 0; l < lis.length; l++ ){
                        if(lis[l].id.indexOf("liProcessNameId") != -1){
                            tmp2.label = lis[l].innerHTML;
                        }
                    }
                    
                    // if commands should be added to the graph we get we add it as a label
                    if(this.addCommandsToGraph == true){
                        tmp2.label = commandConstructor.commandlines.getCommandWithProcessId(process.id);
                    }

                    if(this.showNodesThatAreNotOkToRun == false){
                        
                        // check if all inputs are satisfied
                        var inputIsOk = true;
                        var inputsDiv  = document.getElementById("inputs"  + rowId);
                        var divs = inputsDiv.getElementsByTagName('div');
                        for(var d=0;d<divs.length ; d++){
                            if( divs[d].id.indexOf("target") != -1 ){    // a div that should have a file
                                var objects = divs[d].getElementsByTagName('div');
                                var nrObjects = 0;
                                for(var e=0; e<objects.length; e++){
                                    if( objects[e].id && objects[e].id.indexOf("divObj") != -1 ){  // a object
                                        nrObjects++;
                                    }
                                }
                                if(nrObjects != 1){
                                    inputIsOk = false;
                                    break;
                                }
                            }
                        }

                        if(inputIsOk == true){
                            nodes.push(tmp2);
                        }
                    }
                    else{
                        nodes.push(tmp2);
                    }
                    var divInputs     = document.getElementById('inputs' + rowId);
                    var divInputNodes = divInputs.childNodes;
                    for (var o = 0; o < divInputNodes.length; o++ ){
                        // add all file dragged to graph
                        var inputs = divInputNodes[o].getElementsByTagName('input');
                        for(var b = 0; b < inputs.length; b++) { // should only be one..
                            if( inputs[b].id.indexOf("fileId") != -1 ){
                                processInputs.push(inputs[b].value); // store fileId
                            
                                // add input edge, if an process output draw from that process if not draw from the file
                                var from;
                                if( inputs[b].id.indexOf("fileIdProcessOutput") != -1 ){    // output from a process
                                    // from should be the process_id for the output
                                    var hiddenOutput  = document.getElementById('fileIdProcessOutput' + inputs[b].value);
                                    var outputRow     = getClosestParent(hiddenOutput, 'tr');
                                    var outputRowId   = getRowId(outputRow);
                                    var outputProcess = getRowProcessFromRowUniqueRowId(commandConstructor, outputRowId);
                                    from = outputProcess.id;
                                    // add as a edge
                                    var tmp3   = new Object();
                                    tmp3.from  = from;
                                    tmp3.to    = process.id;
                                    tmp3.label = ' File: ' + inputs[b].value
                                    edges.push(tmp3);   // edge from a processoutput to a node
                                }
                                else {                                                      // ouput from a file
                                    from = inputs[b].value; // use fileId
                                    // add as a edge
                                    var tmp3   = new Object();
                                    tmp3.from  = from;
                                    tmp3.to    = process.id;
                                    edges.push(tmp3);   // edge from a file to a node
                                    
                                    // add it to the files array (will later create the file array seperate but to be sure that the file nodes is 
                                    // only created once I insert them into array here
                                    files.push(from);
                                }
                            }
                        }
                    }
                }
            }
            
            // 2. create the edges for the outputs
            for (var i = 0, row; row = tbl.rows[i]; i++) {
                var rowId = getRowId(row);
                
                if( rowId != 0 ){
                    // here we have a row which is a process
                    var process = getRowProcessFromRowUniqueRowId(commandConstructor, rowId)
                
                    // add all outputs to array
                    var divOutputs     = document.getElementById('outputs' + rowId);
                    var divOutputNodes = divOutputs.childNodes;
                    for (var o = 0; o < divOutputNodes.length; o++ ){
                        if( divOutputNodes[o].classList.contains("okToProcess") ){// add only okToProcess (draggable output nodes) to graph
                            // add green border around output that is ok (the node will have a name which is the same as the process.id)
                            for(var c = 0; c < nodes.length ; c++){
                                if(nodes[c].name == process.id){
                                    if( this.useColors ){
                                        nodes[c].color = "#00a000";
                                    } 
                                    nodes[c].penwidth = "2";
                                }
                            }

                            var inputs = divOutputNodes[o].getElementsByTagName('input');
                            for(var b = 0; b < inputs.length; b++) { // should only be one..
                                if( inputs[b].id.indexOf("fileIdProcessOutput") != -1 ){
                                    // create edge for output if it does not exist as an input
                                    var outputIsNotUsedAsInput = true;
                                    for( var j = 0; j < processInputs.length; j++){
                                        if( inputs[b].value == processInputs[j] ){
                                            outputIsNotUsedAsInput = false;
                                            break;
                                        }
                                    }
                                    if( outputIsNotUsedAsInput ){
                                        // add as a edge, between two commands
                                        var process = getRowProcessFromRowUniqueRowId(commandConstructor, rowId);
                                        var tmp3  = new Object();
                                        tmp3.from = process.id;
                                        tmp3.to   = inputs[b].value;
                                        edges.push(tmp3);
                                        
                                        // add node, outputfile that is not used as input
                                        var tmp4  = new Object();
                                        tmp4.name = inputs[b].value;
                                        tmp4.label= inputs[b].value;
                                        tmp4.shape= 'none';
                                        nodes.push(tmp4);
                                    }
                                }
                            }
                        }
                        else{
                            // add red border around output that is not ok (the node will have a name which is the same as the process.id)
                            for(var c = 0; c < nodes.length ; c++){
                                if(nodes[c].name == process.id){
                                    if( this.useColors ){
                                        nodes[c].color = "#f00000";
                                    } 
                                   nodes[c].penwidth = "2";
                                }
                            }
                        }
                    }
                }
            }
            
            // 3. create the file nodes
            var uniqueFiles = files.unique();
            for(var i = 0; i < uniqueFiles.length; i++ ){
                var tmp4  = new Object();
                tmp4.name      = uniqueFiles[i];
                tmp4.label     = 'File:' + uniqueFiles[i].substring(0,minFileLength) + '...'; // fixes file input nodes to have shorter names
                tmp4.URL       = uniqueFiles[i];
                if( this.useColors ){
                    tmp4.fontcolor = '#0000FF';
                }
                tmp4.shape     = 'none';
                nodes.push(tmp4); 
            }
            
            // add the nodes and edges to the object it self
            this.nodes = nodes;
            this.edges = edges;
        }
    }
    
    /** toJson creates a json for this class to be used in graphviz
     * @returns {object} JSON
     */
    this.toJson = function(){
        // create graph object
        var graph  = new Object();
        graph.edge   = this.edge;
        graph.global = this.global;
        graph.graph  = this.graph;
        graph.node   = this.node;

        // create object that could be sent to server (which creates a graphviz object)
        var tmp      = new Object();
        tmp.graphs   = [ graph ];     
        tmp.nodes    = this.nodes;
        tmp.edges    = this.edges;
        return tmp;
    }

    /** changeAddCommandsToGraph changes the addCommandsToGraph value */
    this.changeAddCommandsToGraph = function(bool){
        this.addCommandsToGraph = bool;
    }

    /** changeShowNodesThatAreNotOkToRun changes the showNodesThatAreNotOkToRun value */
    this.changeShowNodesThatAreNotOkToRun = function(bool){
        this.showNodesThatAreNotOkToRun = bool;
    }

    /** changeUseColors changes the useColors value */
    this.changeUseColors = function(bool){
        this.useColors = bool;
    }
}

/* drag n drop functions */
/**
 *    Functions onDrop(e), onDragOver(e) and onDragStart are needed to use drag n drop.
 *    onDragStart sets the value that should be moved (access to moved object throught e.target).
 *    onDrop executes when the object is dropped, you have access to the moved object data through 
 *        e.dataTransfer.getData(DATATYPE) and the object that it can drop on through e.target.
 *    onDragOver must be set to stop it's normal behaviour (e.preventDefault();) in the droppable objects
 *       for the drop to be able to work.
 *    I have choosen to pass the id of the draggable div on onDragStart and then retrieve it in onDrop.
 *
 *   Objects that are movable are enclosed in div with a hidden input field with id == fileTypeXXX 
 *   (where XXX is an unique id) and a value == FILETYPEID the object is of.
 *   They also have class == draggableItem whith is for css and also for checking how many items a droppable has.
 *    Ex.
 *    <div id="div1" class="draggableItem" ondragstart="onDragStart(event)">
 *        <input type="hidden" id="fileType123" value="2" />
 *    </div>
 *    If draggable div has class == permanent it will copy the div instead of move the div.
 *
 *   Droppable zones are divs that has the class="droppable" and a hidden input field with 
 *   id == allowedFiletypeXXX (where XXX is an unique id) and value == FILETYPEID/FILETYPEIDSSEPERATEDBYCOMMA
 *   A filetype in the database table have subtypes so if you should see a value = 2,3 or similar where 2 = SAMFILE and 3 SORTEDBAMFILE
 *   it should be possible to drop a SAM, BAM, SORTEDBAMFILE but not for instance a ZIPFILE
 *<pre><code>Ex
 *&lt;div id="target1" class="droppable" ondragover="onDragOver(event)" ondrop="onDrop(event)">
 *   &lt;input type="hidden" id="allowedFiletype123" value="2,3" />
 *&lt;/div>
 *</code></pre>
 */
function drop(ev, commandConstructor){
    ev.preventDefault();

    var id = ev.dataTransfer.getData("Text");       // id of element to move/copy
    var element = document.getElementById(id);      // create element
    var classname = element.className;              // get css class of object
    if (classname.indexOf("permanent") != -1) {     // it is permanent, copy the node (which is the div)
        var newObject = element.cloneNode(true);
        
        // create unique id for the object
        newObject.id = createUniqueId('divObj');
        
        // replace objects fileIdRAND or fileIdProcessOutputRAND id with a new RAND
        replaceNodeFileIdAndFileTypeId(newObject);
        
        // remove permanent as class so the object can be moved several times
        var newClassName = element.className;
        newClassName = newClassName.replace("permanent", ""); 
        
        // if it was an output, add the class of draggableOutputItem
        newClassName = newClassName.replace("okToProcess", "draggableOutputItem"); 
        
        newObject.className = newClassName;
        
        // add delete button to object
        var imgDelete = document.createElement("img");
        imgDelete.setAttribute('class', "deleteButton");
        imgDelete.setAttribute('src', document.getElementById('del_no_focus_url').value);
        imgDelete.setAttribute('title', 'delete this file');
        imgDelete.setAttribute('draggable', 'false');
        imgDelete.setAttribute('onmouseover', 'this.src=\'' + document.getElementById('del_focus_url').value + '\'');
        imgDelete.setAttribute('onmouseout',  'this.src=\'' + document.getElementById('del_no_focus_url').value + '\'');
        imgDelete.setAttribute('onclick', "btnRemoveDragAndDropObject(" + commandConstructor.name + ", this);");
        newObject.insertBefore(imgDelete, newObject.firstChild);

        // drop in closest dropzone (parent wise)
        // we check if the old node (element) is allowed to dropped and then insert newObject
        analyseAction( 'insertNodeIntoDroppable', {'commandConstructor': commandConstructor, 'nodeToInsert': newObject, 'nodeToCheck': element, 'target': ev.target } );
    }
    else { // is not permanent, move
        
        // here the item to check is the same as the one to drop
        analyseAction( 'insertNodeIntoDroppable', {'commandConstructor': commandConstructor, 'nodeToInsert': element, 'nodeToCheck': element, 'target': ev.target } );
    }

    // remove all dropzones classes
    clearClassOnDroppables();
}

/** dragOver is called by a droppable zone when a dragged item is dragged over it. It only prevent the default behaviour that is to not allow a drop. */
function dragOver(ev){
    ev.preventDefault();
}

/** dragStart is called when a dragged item is started to be dragged.
 * It is in dragStart that the data to be dragged are set and also all droppable zones classes are updated.
 */
function dragStart(ev, commandConstructor){
    ev.dataTransfer.setData("Text", ev.target.id); // set the dragged items id as the data (in onDrop it will handle what to do with it) (the item dragged is the div)
    // highlight all avaible droppable zones
    var elems = document.getElementsByClassName('droppable'); // get all droppable objects on the page
    for (var i = 0; i < elems.length; i++) {
        changeClassOnDroppable(commandConstructor, elems[i], ev.target); // class will either be "okToDrop", "notOkToDrop"
    }
}

/** dragEnd is called when a dragged item has been dropped.
 * dragEnds only function is to clear all the classes on the dropzones.
 */
function dragEnd(ev, commandConstructor) {
    clearClassOnDroppables();
}

/** replaceNodeFileIdAndFileTypeId replaces a draggable objects fileId and fileTypeId. 
 * It is used when copying a object on the screen because the copy are not allowed to have the 
 * same id as the object it was copied from because of the DOM 
 */
function replaceNodeFileIdAndFileTypeId(node){
    
    var childrens = node.childNodes;
    for (var i = 0; i < childrens.length; i++) {
        if( childrens[i].id && childrens[i].id.indexOf("fileId") != -1 && childrens[i].id.indexOf("fileIdProcess") == -1 ){
            childrens[i].id = createUniqueId('fileId');
        }
        else if( childrens[i].id && childrens[i].id.indexOf("fileIdProcess") != -1) {
            childrens[i].id = createUniqueId('fileIdProcessOutput');
        }
        else if( childrens[i].id && childrens[i].id.indexOf("fileType") != -1) {
            childrens[i].id = createUniqueId('fileType');
        }
    }
}

/** analyseAction group many of the important actions on the analyse page to a central function.
 * The analyseAction function was created to be able to have a better overview of what actions triggers what css and graph updates.
 * @example example code
 *&lt;button onclick="analyseAction('test', {'commandConstructor':
  'clientCommandConstructor','object':this,'id':'42'})">test action&lt;/button>
 */
function analyseAction(name, parameters){
    // many actions use same parameters, here I exctract those
    var commandConstructor = parameters['commandConstructor'];
    var object             = parameters['object'];

    switch(name){
        case 'addInputToInputs':
            // Adds a input field for a file in the parameter window
            var clickedButton = object;
            addInputToInputs(commandConstructor, clickedButton);
            refreshDragAndDropTable(commandConstructor);// refresh drag and drop table, in that function a updateProcessParameterValuesFromTable call is made to update with new values
            break;
        case 'changeProcessDescription':
            var input     = object;
            var processId = parameters['processId'];            
            var process = commandConstructor.processes.get(processId);
            var newDescription = input.value;
            if(input.value == ''){// get name of command
                newDescription = commandConstructor.commands.get(process.command_id).description;
                input.value = newDescription; 
            }
            process.description = newDescription; // the description is not shown in either graph or in the table, if that where the case that must be updated
            break;
        case 'changeProcessName':
            var input     = object;
            var processId = parameters['processId'];
            var process   = commandConstructor.processes.get(processId);
            var newName   = input.value;
            if(input.value == ''){// get name of command
                newName = commandConstructor.commands.get(process.command_id).iname;
                input.value = newName;
            }
            process.iname = newName;
            // Update name and refresh the graph for each stroke (must because the position of the names and nodes will change with longer names)
            // get name from li with name liProcessNameIdRAND
            var inputs = document.body.getElementsByTagName('input'); // not good with body... 
            for (var i = 0; i < inputs.length; i++ ){
                if(inputs[i].id.indexOf("hiProcessId") != -1){
                    if(inputs[i].value == processId){ 
                        var row = getClosestParent(inputs[i], 'tr');
                        var lis = row.getElementsByTagName('li');
                        for (var l = 0; l < lis.length; l++ ){
                            if(lis[l].id.indexOf("liProcessNameId") != -1){
                                lis[l].innerHTML = newName;
                                break;
                            }
                        }
                        break;
                    }
                }
            }
            commandConstructor.updatePreviewGraph();
            break;
        case 'editGraphvizObject':
            commandConstructor.previewgraph.showEditDialog();
            break;
        case 'insertNodeIntoDroppable':
            var nodeToInsert = parameters['nodeToInsert'];
            var nodeToCheck  = parameters['nodeToCheck'];
            var target       = parameters['target'];
            if( insertNodeIntoDroppable(commandConstructor, nodeToInsert, nodeToCheck, target) ){ // the dragged item was not a process output, see function for better explanation
                removeAllNotValidOutputs(commandConstructor);
            }
            commandConstructor.updateProcessParameterValuesFromTable('tblProcesses'); // when a dragAndDrop object is removed or inserted the commandConstructor.processparametervalues are updated
            updateAllDroppableClasses();// this updateAllDroppableClasses() is called to update the output color of the output box and not primarily to fix the droppables color
                                        // this is because the action 'insertNodeIntoDroppable' is only called from the function called drop which has a function call to
                                        // clearClassOnDroppables(), which will remove all droppables classes that updateAllDroppableClasses updates.
                                        // the function is though fast enough so I have not created a seperate updateAllOutputClasses function and besides if this function later on
                                        // will be called from an other function the output will be correct when the clearClassOnDroppables is not called
            commandConstructor.updatePreviewGraph();// update preview of graph
            break;
        case 'refreshDragAndDropTable':
            commandConstructor.dependencies = new Dependencies(); // remove all dependencies, if left when a refresh is done old dependencies will exist, 
                                                                  // not a good ide (they will be added when the files are added)
            var addDraggedFiles = true;
            createTable(commandConstructor, 'liBuildRun', addDraggedFiles);
            removeAllNotValidOutputs(commandConstructor);
            commandConstructor.updateProcessParameterValuesFromTable('tblProcesses'); // when a dragAndDrop object is removed or inserted the commandConstructor.processparametervalues are updated
            updateAllDroppableClasses();
            commandConstructor.updatePreviewGraph();// update preview of graph
            break;
        case 'removeDragAndDropObject':
            // Removes the drag and drop object in the drag and drop table 
            var button    = object;
            var divObject = getClosestParentDiv(button);
            removeDragAndDropObject(commandConstructor, divObject);
            removeAllNotValidOutputs(commandConstructor);
            
            commandConstructor.updateProcessParameterValuesFromTable('tblProcesses'); // when a dragAndDrop object is removed or inserted the commandConstructor.processparametervalues are updated
            updateAllDroppableClasses();
            commandConstructor.updatePreviewGraph();// update preview of graph
            break;
        case 'removeInputFromInputs':
            // Removes a input file from the parameter window, triggers a refresh on the hole table
            var clickedButton = object;
            removeInputFromInputs(commandConstructor, clickedButton); // removes and updates the parameterdialog inputs and commandconstructors.processparametervalues,
                                                                      // makes the draganddroptable obsolete(have to refresh)
            refreshDragAndDropTable(commandConstructor);              // takes values from commandconstructor and tries to recreate the drag and drop table
            break;
        case 'removeProcess':
            // Removes the process from the drag and drop table
            var processId = parameters['processId'];
            var button    = object;
            var table     = getClosestParent(button, 'table');
            removeProcess(commandConstructor, button, processId);
            if( table.rows.length == 1){// remove table if only one row exist (which is the header row)
                var tblParent = table.parentNode;
                tblParent.removeChild(table);
                document.getElementById('divPreviewGraph').innerHTML = ''; // remove the preview graph
                updateAllJobButtonsClasses();                              // will hide the buttons   
            }
            else{
                removeAllNotValidOutputs(commandConstructor);// remove outputs, there is a check if there is no rows but I only call it if there exist a table
                updateAllDroppableClasses();
                commandConstructor.updatePreviewGraph();// update preview of graph
            }
            break;
        case 'updateGraphvizObject':
            var properties = parameters['properties'];
            commandConstrutor.previewgraph.update(properties);
            commandConstructor.updatePreviewGraph();// update preview of graph
            break;
        case 'updateParameterUsage':
            var checkBox = object;
            if( updateParameterUsage(commandConstructor, checkBox) ){ // returns if drag and drop table needs to be refreshed
                refreshDragAndDropTable(commandConstructor);
            }
            break;
        default:
            // default is to do noting, almost
            alert("Have no information how to exeucute command " + name + ".");
    }
}


/** updateAllDroppableClasses updates all droppables classes in the drag and drop table.
 * If a item has been dropped or started to be dragged the color of the droppable areas are highlighted with a color indicating if it is possible to drop there or not.
 * updateAllDroppableClasses updates/adds the hasObject or hasNotObject class depending if the object has an object or not.
 * It also calls a function that updates the color of the job buttons with updateAllJobButtonsClasses call last in this class (this is because the updateAllDroppableClasses 
 * are called from several places and to avoid to have to call updateAllJobButtonsClasses on those places the call was inserted here)
 */
function updateAllDroppableClasses(){

    // update all droppables with correct class name (either hasNotObject or hasObject)
    var elems = document.getElementsByClassName('droppable');               // get all droppable objects on the page (defined by class)
    for (var i = 0; i < elems.length; i++) {                                // for each droppable
        var nrObjects = getNrObjectsDroppableHas(elems[i]);
        elems[i].className = nrObjects == 1 ? addAndRemoveString(elems[i].className, "hasObject", "hasNotObject") : addAndRemoveString(elems[i].className, "hasNotObject", "hasObject");
        removeClasses(elems[i], ['okToDrop', 'notOkToDrop']);
    }
    
    // update all outputs with correct color (if all inputs are satisfied)
    // go through all process table rows, if all inputs are ok, set output to ok... and create a object that is draggable from the output, also add it to javascript object
    var tbl = document.getElementById('tblProcesses');
    if(tbl){
        for (var i = 0, row; row = tbl.rows[i]; i++) {        // rows: both header, footer and content
            var nrInputs = 0;
            var nrInputsOk = 0;
            var allInputsOk = false;
            var rowId = getRowId(tbl.rows[i]);
            
            var droppables = [];
            droppables = getDroppables(row);
            if(droppables){
                nrInputs = droppables.length;
            
                for (var a = 0; a < droppables.length; a++) {
                    if( getNrObjectsDroppableHas(droppables[a]) == 1 ) {
                        nrInputsOk++;
                    }
                }
                
                if(nrInputs > 0 && nrInputs == nrInputsOk){ // is there any rows that could have output but no input? if so how to see the difference between them and a header row?
                    allInputsOk = true;
                }
            }
            
            var divOutputs = document.getElementById('outputs' + rowId);
            if(divOutputs){
                // get childnodes (outputs) and set their class to okToProcess if all is ok
                var divOutputNodes = divOutputs.childNodes;
                for (var b = 0; b < divOutputNodes.length; b++ ){
                    if(allInputsOk){
                        addClasses(divOutputNodes[b], ["okToProcess"]);
                        divOutputNodes[b].setAttribute('draggable', true);
                    }
                    else{
                        removeClasses(divOutputNodes[b], ["okToProcess"]);
                        divOutputNodes[b].setAttribute('draggable', false);
                    }
                }
            }
            
        }
    }
    
    // update color all job buttons
    updateAllJobButtonsClasses();
}

/** updateAllJobButtonsClasses changes the classes on the 'Preview Job', 'Save as template' 
 * and 'Create job' buttons and hides the enclosing li if of the buttons if there is no table rows in the table.
 */
function updateAllJobButtonsClasses(){
    var enclosingObject = document.getElementById('liJobButtons');
    var tbl = document.getElementById('tblProcesses');
    
    if( !tbl || tbl && tbl.rows.length <= 1){// if only header row exist, hide the buttons too
        enclosingObject.className  = addAndRemoveString( enclosingObject.className, "hidden", '');
    }
    else{
        enclosingObject.className  = addAndRemoveString( enclosingObject.className, '', "hidden");
    }
    
    var preview  = document.getElementById('btnShowCommandPreview');
    var template = document.getElementById('btnSaveCommandsAsTemplate');
    var save     = document.getElementById('btnSaveCommandsAsProcess');

    if( checkAllInputsOkToRun() ){
        preview.className  = addAndRemoveString( preview.className, "btnJobOkToPress", "btnJobNotOkToPress");
        template.className = addAndRemoveString(template.className, "btnJobOkToPress", "btnJobNotOkToPress");
        save.className     = addAndRemoveString(    save.className, "btnJobOkToPress", "btnJobNotOkToPress");
    }
    else{
        preview.className  = addAndRemoveString( preview.className, "btnJobNotOkToPress", "btnJobOkToPress");
        template.className = addAndRemoveString(template.className, "btnJobNotOkToPress", "btnJobOkToPress");
        save.className     = addAndRemoveString(    save.className, "btnJobNotOkToPress", "btnJobOkToPress");
    }
}

/** isProcessInTable returns true if given process is in the drag and drop table and false otherwise 
  * @returns {boolean} true if process is in table and false if it is not
  */
function isProcessInTable(commandConstructor, processId, tblId){
    var tbl = document.getElementById(tblId);
    if(tbl){
        for (var i = 0, row; row = tbl.rows[i]; i++) {              // create array of unique id's for each row (all the steps)
             var id = getRowId(row);
             if( id != 0 ){// not working on header row
                var process = getRowProcessFromRowUniqueRowId(commandConstructor, id);
                if(process.id == processId){
                    return true;
                }    
             }
        }
    }
    return false;
}

/** getRowId returns the unique row id from a row if it exist and 0 if it did not find any row id, each row has a div with id processYYY 
 * where the YYY is the row id (at the moment it is the first cell of the table 
 * @returns {numeric} id of the row or 0 if none was found 
 */
function getRowId(rowNode){
    for (var i = 0, col; col = rowNode.cells[i]; i++){
        var colNodes = col.childNodes;
        for (var j = 0; j < colNodes.length; j++) {   // nodes
            if (colNodes[j].id && colNodes[j].id.indexOf("processes") != -1){
                return colNodes[j].id.replace("processes", "");
            }
        }
    }
    return 0;
}

/** getRowProcessFromRowUniqueRowId returns a Process class object for a given uniqueRowId. 
 * If it fails to find any it shows an error dialog telling it did not find any processId on the row. 
 * @returns {numeric|undefined} process_id if it was found, undefined otherwise (will not return a value)
 */
function getRowProcessFromRowUniqueRowId(commandConstructor, uniqueRowId){
    // get first the processes div
    var node = document.getElementById("processes" + uniqueRowId);
    var children = node.childNodes;
    for ( var i = 0; i < children.length ; i++){
        if( children[i].id && children[i].id.indexOf("hiProcessId") != -1){
            return commandConstructor.processes.get(children[i].value);
        }
    }
    showDialog("error, no processid at unique row from function getRowProcessFromRowUniqueRowId", "Error");
}

/** getDraggables returns all the nodes that has the class "draggableItem" in the node or its childrens 
 * @returns {object[]|undefined} all nodes that has the class "draggableItem"
 */
function getDraggables(node) {
    var nodes = [];
    if (node.className && node.className.indexOf("draggableItem") != -1) {
        nodes.push(node);
    }
    var childrens = node.childNodes;
    for (var i = 0; i < childrens.length; i++){
        var n = getDraggables(childrens[i])
        if( n ){
            for(var j = 0; j < n.length; j++){
                nodes.push(n[j]);
            }
        }
    }
    if(nodes.length > 0){
        return nodes;
    }
}

/** getDroppables returns all the nodes that has the class "droppable" in the node or its childrens 
 * @returns {object[]|undefined} all nodes that has the class "droppable"
 */
function getDroppables(node) {
    var nodes = [];
    if (node.className && node.className.indexOf("droppable") != -1) {
        nodes.push(node);
    }
    var childrens = node.childNodes;
    for (var i = 0; i < childrens.length; i++){
        var n = getDroppables(childrens[i])
        if( n ){
            for(var j = 0; j < n.length; j++){
                nodes.push(n[j]);
            }
        }
    }
    if(nodes.length > 0){
        return nodes;
    }
}

/** getObjects returns all the nodes that has the id that contains "divObj" in the node or its childrens 
 * @returns {object[]|undefined} all nodes that has the class "divObj"
 */
function getObjects(node) {
    var nodes = [];
    if (node.id && node.id.indexOf("divObj") != -1) {
        nodes.push(node);
    }
    var childrens = node.childNodes;
    for (var i = 0; i < childrens.length; i++){
        var n = getObjects(childrens[i])
        if( n ){
            for(var j = 0; j < n.length; j++){
                nodes.push(n[j]);
            }
        }
    }
    if(nodes.length > 0){
        return nodes;
    }
}

/** getObjectType returns the type of a object. The object is a divNode with id that contains 'divObj' and 
 * has hidden input as a child with a id of either fileIdNR or fileIdProcessNR.
 * @returns {string} 'file', 'stepOutput' or 'none'. 
 */
function getObjectType(node) {
    var childrens = node.childNodes;
    for (var i = 0; i < childrens.length; i++) {
        if( childrens[i].id && childrens[i].id.indexOf("fileId") != -1 && childrens[i].id.indexOf("fileIdProcess") == -1 ){
            return 'file';
        }
        else if( childrens[i].id && childrens[i].id.indexOf("fileIdProcess") != -1) {
            return 'stepOutput';
        }
    }
    return 'none';
}

/** getObjectFileId returns the fileId of a object. The object is a divNode with id that contains 'divObj' and has hidden input as a child with a id of either fileIdNR or fileIdProcessNR.
 * @returns {numeric} id of the file or -1 if nonexisting. Either hash number if it was a existing file in the system or otherwise a random number if the file does not exist yet.
 */
function getObjectFileId(node) {
    var childrens = node.childNodes;
    for (var i = 0; i < childrens.length; i++) {
        if( childrens[i].id && childrens[i].id.indexOf("fileId") != -1 && childrens[i].id.indexOf("fileIdProcess") == -1 ){
            return childrens[i].value; // an existing file in the system, the value is the hash
        }
        else if( childrens[i].id && childrens[i].id.indexOf("fileIdProcess") != -1) {
            return childrens[i].value; // and file that will be created, the value is a random number
        }
    }
    return -1;
}

/** getDroppableProcessParameterValueInputId returns a droppable (div which has a class of droppable) processParameterValueId if it exist, and -1 if not
 * @returns {numeric} -1 if nonexisting otherwise the droppable processParameterValueId
 */
function getDroppableProcessParameterValueInputId(node){
    var childrens = node.childNodes;
    for (var i = 0; i < childrens.length; i++) {
        if( childrens[i].id && childrens[i].id.indexOf("processParameterValueInputId") != -1){
            return childrens[i].value;
        }
    }
    return -1;
}

/** getNrObjectsDroppableHas returns the number of objects (a div with id contains 'divObj') a node has 
 * @returns {numeric} nr objects the droppable has (0 if none exists)
 */
function getNrObjectsDroppableHas(droppableNode){
    var nodes = droppableNode.childNodes;
    var nrObj = 0
    for (var i = 0; i < nodes.length; i++) {                         // count nr objects the droppable has
        if (nodes[i].id && nodes[i].id.indexOf("divObj") != -1) {
            nrObj += 1;
        }
    }
    return nrObj;
}

/** createUniqueId returns a unique id with given prefix.
 * The unique id gets the value of PREFIXRAND where RAND is betweene 0 and 32767.
 * If the function can not find a unique id, it will end up in a endless loop. 
 * @returns {string|numeric} a random number betweene 0 and 32767 with given prefix
 */
function createUniqueId(prefix){
    var newId;
    while(newId = prefix + Math.floor(Math.random() * 32767) ){
        if( null == document.getElementById(newId) ){
            return newId;
        }
    }
}
/** insertNodeIntoDroppable inserts a object file (div with id contains 'divObj') into a droppable (div which has a class of droppable).
 * To be able to insert a newly created node you have to have information only known in the old object (process_id, may be more later on)
 * this is because you can not get information where the newly created item is copied from (it has not been inserted into the dom)
 * so we check that the old node is possible to drop at the new place and if it does we insert the new one (which is just a copy of the old node with some minor id adjustments) 
 * @returns {boolean} true if after the function it need to remove all not valid outputs, otherwise false
 */
function insertNodeIntoDroppable(commandConstructor, nodeToInsert, nodeToCheck, target) {
    var needToRemoveAllNotValidOutputs = false;
    
    // get closest droppable
    var droppableNode = getClosestDroppableObject(target);
    if ( isAllowedToDrop(commandConstructor, nodeToCheck, droppableNode) ) { // check if allowed to drop here
        droppableNode.appendChild(nodeToInsert);                             // insert it
        
        if( isDraggedItemAnOutputFromAProcess(nodeToCheck) ){ // if it is output from an other node add a dependency 
            // get dragged proccessId
            var divDraggedProcessId = getDraggedProcessParameterValueOutputProcessId(commandConstructor, nodeToCheck); // get draggable divs processId
            var divTargetProcessId  = getTargetProcessId(commandConstructor, droppableNode);
            // add dependency
            var dependency = new Dependency();
            dependency.set(divTargetProcessId, divDraggedProcessId, 0);// uses level == 0, does not meen anything
            commandConstructor.addDependency(dependency);
        }
        else{
            // after you have inserted a node, the node origins row may have been changed (moved a object from a complete row, which after the move is not finished)
            // if it is a outputfile from a process, that process can never have changed status but if it was not a outputfile, it may.
            // so is the old row still ok or is it incomplete?.. to complicated to execute, better to just remove all nonvalid outputs from all processes..
            needToRemoveAllNotValidOutputs = true;
        }
    }
    return needToRemoveAllNotValidOutputs;
}

/** isDraggedItemAnOutputFromAProcess returns true if the dragged item is an output from a process.
 * When a file is starting to be dragged the dragged item could be either: 
 * 1. a existing file from the system
 * 2. a output from a process
 * 3. a file previously dragged from an existing file
 * it is only case 2 where you have to check for dependency loops 
 * @returns {boolean} true if dragged item is an item from a process, false if it is not a output from a process
 */
function isDraggedItemAnOutputFromAProcess(node){
     var type = getObjectType(node); // returns either 'file', 'stepOutput' or 'none'
     return type == 'stepOutput' ? true : false;
}

/** getDraggedProcessParameterValueOutputProcessId returns the process_id of a dragged object 
 * by finding the objects hiden processParameterValueOutputId and extracting the process_id from the commandconstructor 
 * @returns {numeric|undefined} processId
 */
function getDraggedProcessParameterValueOutputProcessId(commandConstructor, node){
    // get inputs
    var processParameterValueId = '';
    var inputs = node.getElementsByTagName('input');
    for(var i = 0; i < inputs.length; i++) {
        // get processparametervalue
        if( inputs[i].id.indexOf("processParameterValueOutputId") != -1 ){
            processParameterValueId = inputs[i].value;
            break;
        }
    }
    // get process_id from commandconstructor
    return commandConstructor.processparametervalues.get(processParameterValueId).process_id;
}

/** getDraggedRowProcessId returns the processId for the row that the object exist on 
 * @returns {numeric|undefined} processId
 */
function getDraggedRowProcessId(commandConstructor, node){
    var processId;
    var row = getClosestParentRow(node);
    var inputs = row.getElementsByTagName('input');
    for(var i = 0; i < inputs.length; i++) {
        // get processId
        if( inputs[i].id.indexOf("hiProcessId") != -1 ){
            processId = inputs[i].value;
            break;
        }
    }
    return processId;    
}

/** getTargetProcessId returns the processId of a target (droppable zone), the node must be a div that is droppable 
 * @returns {numeric|undefined} processId
 */
function getTargetProcessId(commandConstructor, node){
    // get target processId
    var divInputs           = node.parentNode;      // targets parent is the divinputs where all inputs exist, get the id of the unique row from it and call function get process from row
    var rowId               = getLastNumber(divInputs.id);
    var divDroppProcess     = getRowProcessFromRowUniqueRowId(commandConstructor, rowId);
    return divDroppProcess.id;
}

/** isAllowedToDrop returns either true or false if the node is allowed to drop onto the target node 
 *  When a file is starting to be dragged the dragged item could be either:
 *  1. a existing file from the system
 *  2. a output from a process
 *  3. a file previously dragged from an existing file
 *
 *  if 1 and 3 it will contain a hidden id in the div which has the name fileIdNUMBER, where NUMBER is a RAND for 3. and HASH for 1.
 *  if 2 it is a created dummy value inserted into the process id
 *  fileIdMD5                            -- if from existing file
 *  processParameterValueOutputId22773   -- if from a output
 *  fileId7293                           -- if a dragged file 
 *  @returns {boolean} true if it is allowed to drop, false if it is not allowed to drop
 */
function isAllowedToDrop(commandConstructor, node, target) {
    var isAllowed = false;
    
    // first check the filetype
    // if node's hidden child called fileType is mentioned in target's hidden field allowedFiletype it is allowed
    var fileTypeId = getDraggedItemsFileType(node);// get nodes fileTypeId value
    isAllowed = doesNodeAcceptFileTypeId(commandConstructor, target, fileTypeId);
    
    // then check for dependency loops:
    // 1. get if dragged item is an output from a process. (if not it is ok to drop because it has no dependencies)
    // 2. if dragged item is an ouput check if that item is allowed to drop in the dropdiv (get process id from droppable and draggable and check for dependency loop)
    var type = getObjectType(node); // returns either 'file', 'stepOutput' or 'none'
    if( type == 'stepOutput' ){     // check if it is an output check that no dependency loop will be created if dropped  

        var divDraggedProcessId = getDraggedProcessParameterValueOutputProcessId(commandConstructor, node); // get draggable divs processId
        var divDroppProcessId   = getTargetProcessId(commandConstructor, target);   // get target processId
        
        if( divDraggedProcessId == divDroppProcessId){ // can't drop a output as a input for it self
            // get dropped process
            isAllowed = false;
        }
        else{
            // get dragged dependencies, and then check if target processId exist
            var dependencies        = commandConstructor.dependencies.get_all_with_process_id_recursivly(divDraggedProcessId);
            var dependencies2       = commandConstructor.dependencies.get_all_with_process_id_recursivly(divDroppProcessId);
            for( var i = 0; i < dependencies.dependency.length; i++ ){
                if( dependencies.dependency[i].parent_process_id == divDroppProcessId){
                    isAllowed = false; // the droppable processObject has a dependency of this process already, will lead to dependency loop
                    break;
                }
            }
        }
    }
    
    return isAllowed;
}

/** getClosestDroppableObject recursivly traverse the node and its parents to find a node which have the class 'droppable'
 * when it finds it, it will return that node. It traverse a maximum of 20 steps in depth before stopping. 
 * returns {object|undefined} object with class of "droppable" or nothing if no parent within 20 steps had that class
 */
function getClosestDroppableObject(node) {
    var className = node.className;
    if (className.indexOf("droppable") != -1) {
        return node;
    }
    else {
        var parent = node.parentNode;
        for (var i = 0; i < 20; i++) { // check at most 20 steps (depth)
            var className = parent.className;
            if (className.indexOf("droppable") != -1) {
                return parent;
            }
            else {
                parent = parent.parentNode;
            }
        }
    }
}

/** getDraggedItemsFileType returns the filetype of a given node 
 * returns {object|undefined} filetype of the node if it existed a child with id containing fileType in its id, otherwise undefined
 */
function getDraggedItemsFileType(node) {
    var draggedItem = node;
    var children = draggedItem.childNodes;
    var fileType;
    for (var j = 0; j < children.length; j++) {
        if (children[j].id && children[j].id.indexOf("fileType") != -1) {
            fileType = children[j].value;
        }
    }
    return fileType;
}

/** getClosestParent returns closest parent with html type of type to the node object. It searches maximum 10 steps
 * returns {object|undefined} object of type type otherwise undefined
 */
function getClosestParent(obj, type){
    var node = obj.parentNode;
    for (var i = 0; i < 10; i++) { // check at most 10 steps (depth)
        var parent = node.parentNode;
        if (node.tagName.toLowerCase() == type) {
            return node;
            break;
        }
        else {
            node = parent;
        }
    }
}

/** getClosestparentDiv return the closest parent div to the node 
 * returns {object|undefined} object of type div otherwise undefined
 */
function getClosestParentDiv(button_this) {
    var node = button_this.parentNode;
    for (var i = 0; i < 10; i++) { // check at most 10 steps (depth)
        var parent = node.parentNode;
        if (node.tagName.toLowerCase() == 'div') {
            return node;
            break;
        }
        else {
            node = parent;
        }
    }
}

/** getClosestparentTable return the closest parent table to the node 
 * returns {object|undefined} object of type table otherwise undefined
 */
function getClosestParentTable(obj) {
    var node = obj.parentNode;
    for (var i = 0; i < 10; i++) { // check at most 10 steps (depth)
        var parent = node.parentNode;
        if (node.tagName.toLowerCase() == 'table') {
            return node;
            break;
        }
        else {
            node = parent;
        }
    }
}

/** getClosestparentRow return the closest parent row to the node
 * returns {object|undefined} object of type tr otherwise undefined
 */
function getClosestParentRow(obj) {
    var node = obj.parentNode;
    for (var i = 0; i < 10; i++) { // check at most 10 steps (depth)
        var parent = node.parentNode;
        if (node.tagName.toLowerCase() == 'tr') {
            return node;
            break;
        }
        else {
            node = parent;
        }
    }
}

/** getClosestparentLi return the closest parent li to the node 
 * returns {object|undefined} object of type li otherwise undefined
 */
function getClosestParentLi(obj) {
    var node = obj.parentNode;
    for (var i = 0; i < 10; i++) { // check at most 10 steps (depth)
        var parent = node.parentNode;
        if (node.tagName.toLowerCase() == 'li') {
            return node;
            break;
        }
        else {
            node = parent;
        }
    }
}

/** getClosestparentSpan return the closest parent span to the node 
 * returns {object|undefined} object of type span otherwise undefined
 */
function getClosestParentSpan(obj) {
    var node = obj.parentNode;
    for (var i = 0; i < 10; i++) { // check at most 10 steps (depth)
        var parent = node.parentNode;
        if (node.tagName.toLowerCase() == 'span') {
            return node;
            break;
        }
        else {
            node = parent;
        }
    }
}

/** deleteClosestParentDiv deletes the closest parent div to the node. Used when removing objects which is of type div.
 * returns {object|undefined} object of type div otherwise undefined
 */
function deleteClosestParentDiv(button_this) {
    var node = button_this.parentNode;
    for (var i = 0; i < 10; i++) { // check at most 10 steps (depth)
        var parent = node.parentNode;
        if (node.tagName.toLowerCase() == 'div') {
            parent.removeChild(node);
            break;
        }
        else {
            node = parent;
        }
    }
}

/** clearClassOnDroppables removes the classes of okToDrop and notOkToDrop on all objects with the class of droppable. */
function clearClassOnDroppables() {
    var elems = document.getElementsByClassName('droppable'); // get all droppable objects on the page
    for (var i = 0; i < elems.length; i++) {
        removeClasses(elems[i], ["okToDrop", "notOkToDrop"]);
    }
}

/** addClasses adds all classes inside classNames to the element */
function addClasses(elem, classNames) {
    var className = elem.className;
    for (var i = 0; i < classNames.length; i++) {
        if(className.indexOf(classNames[i]) == -1){ // only add if it doesn't already has it
            className = classNames[i] + ' ' + className;
        }
    }
    elem.className = className.replace("  ", " ");
}

/** removeClasses removes all classes inside classNames of the element */
function removeClasses(elem, classNames) {
    var className = elem.className;
    for (var i = 0; i < classNames.length; i++) {
        className = className.replace(classNames[i], "");
    }
    elem.className = className;
}

/** changeClassOnDroppable sets the droppable class to either okToDrop or notOkToDrop depending if the dragged item is droppable or not into the droppable */
function changeClassOnDroppable(commandConstructor, droppable, dragged){
    var node    = dragged;
    var target  = droppable;
    if ( isAllowedToDrop(commandConstructor, node, target) ) {    
        // this droppable is ok to drop this dragged item to, so add class okToDrop if it not already has it
        target.className = addAndRemoveString(target.className, "okToDrop", "notOkToDrop");
    }
    else {
        // this droppable is not ok to drop this dragged item to, so remove okToDrop class and add notOkToDrop
        target.className = addAndRemoveString(target.className, "notOkToDrop", "okToDrop");
    }
}

/** doesNodeAcceptFileTypeId returns true or false dending if the node accepts or does not accept a file with fileTypeId 
 * @returns {boolean} true of node accept a filetype with fileTypeId, false if node does not accept a filetype with fileTypeId
 */
function doesNodeAcceptFileTypeId(commandConstructor, node, fileTypeId) {
    var children = node.childNodes;
    for (var i = 0; i < children.length; i++) {
        if (children[i].id && children[i].id.indexOf("allowedFiletype") != -1) {
            if( children[i].value ){
                var nodeFiletypes = children[i].value;
                var arrFiletypeIds = nodeFiletypes.split(",");
                for( var j = 0; j < arrFiletypeIds.length; j++ ){
                    var nodeFiletype = arrFiletypeIds[j];
                    if( isFiletypeATypeOrSubtypeOfFiletype(commandConstructor, fileTypeId, nodeFiletype ) ) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

/** isFileTypeATypeOrSubtypeOfFiletype returns true if the filetypeId is the same type or a subtype of toCheckAgainstFiletypeId otherwise it returns false
 * @returns {boolean} true if the filetypeId is the same type or a subtype of toCheckAgainstFiletypeId otherwise it returns false
 */
function isFiletypeATypeOrSubtypeOfFiletype(commandConstructor, filetypeId, toCheckAgainstFiletypeId){
    var filetypes = commandConstructor.filetypes.get_all_with_filetype_id_recursivly(filetypeId);
    for(var i = 0; i < filetypes.filetype.length; i++) {
        var f = filetypes.filetype[i];
        if( f.id == toCheckAgainstFiletypeId ){
            return true;
        }
    }
    return false;
}

/** hassCssClass checks if a node has a css class, it returns either true or false 
 * @returns {boolean} true if string nodeClassNames contains nameOfClass, otherwise false
 */
function hasCssClass(nameOfClass, nodeClassNames) {
    // split classNames
    var classNamesArray = nodeClassNames.split(" ");
    for (var i = 0; i < classNamesArray.length; i++) {
        if (nameOfClass == classNamesArray[i]) {
            return true;
        }
    }
    return false;
}

/** addAndRemoveString adds toAdd to the str and removes toRemove to the string 
 * @returns {string} with toAdd added and toRemove removed from the input str
 */
function addAndRemoveString(str, toAdd, toRemove) {
    // add toAdd
    if (str.indexOf(toAdd) == -1) {
        str += ' ' + toAdd;
    }

    // remove toRemove
    if (str.indexOf(toRemove) != -1) {
        str = str.replace(toRemove, "");
    }
    str = str.replace("  ", " "); // classes never has "  ", replace those with " "
    return str;
}

/** deleteParentNode removes the parent node of the node */
function deleteParentNode(button_this) {
    var node = button_this.parentNode;
    node.parentNode.removeChild(node);
}

/** deleteNode deletes the node with the id of id */
function deleteNode(id) {
    var node = document.getElementById(id);
    var parent = node.parentNode;
    parent.removeChild(node);
}


/**
 * @class Step describes a step in a execution. Each command is stored in a process and when each process is executed it is called a step.
 * @property {Process} process process is the process associated to this step
 * @property {string} uniqueId uniqueId is a unique id describing the process, the one used is the unique row id
 * @property {StepInputs} stepInputs stepInputs is a StepInputs object that stores all inputs for the step
 * @property {StepOutputs} stepOutputs stepOutputs is a StepOutputs object that stores all outputs for the step
 */
function Step() {
    this.process;
    this.uniqueId;
    this.stepInputs  = new StepInputs();
    this.stepOutputs = new StepOutputs();

    /** set sets the Step properties */
    this.set = function(process, uniqueId, stepInputs, stepOutputs){
        this.process     = process;
        this.uniqueId    = uniqueId;
        this.stepInputs  = stepInputs;
        this.stepOutputs = stepOutputs;
    }
    
    /** getIfExistOutputWithUniqueId returns true if there exist a output with given uniqueId 
     * @returns {boolean} true if there exist a output with given uniqueId  otherwise false
     */
    this.getIfExistOutputWithUniqueId = function(uniqueId){
        return this.stepOutputs.getWithUniqueId(uniqueId) ? true : false;
    }

    /** toJson returns a json representation of the Step object with values for process_id, parameter_id, value and locus
     * @returns {object} JSON representation of a step
     */
    this.toJson = function(commandConstructor, step){
        var processParameterValues = commandConstructor.processparametervalues.getWithProcessId(this.process.id);// get a rows processParameterValues (all processParameterValues with process_id)
        var ps = commandConstructor.parameters.getWithIds(processParameterValues.getParameterIds());             // get all parameters for that rows processParameterValues
        ps.parameter.sort(ps.compareLocus); // sort on locus
        var result = '';
        var p = [];
        for (var i = 0; i < ps.parameter.length; i++){                                        // for each parameter
            var parameter = ps.parameter[i];
            var parameterValues = processParameterValues.getWithParameterId(parameter.id);    // get processParameterValue
            parameterValues.processparametervalue.sort(parameterValues.compareLocus);         // sort them with regards to locus
            for(var j = 0; j< parameterValues.processparametervalue.length; j++){             // for each processParameterValue for the parameter, build command
                var ppv = parameterValues.processparametervalue[j];                           // value  
                var inputName  = this.stepInputs  ? this.stepInputs.getFileNameWithProcessParameterValueId(ppv.id)  : '';   // if a file the md5 or new file alias is stored in stepInputs or stepOutputs
                var outputName = this.stepOutputs ? this.stepOutputs.getFileNameWithProcessParameterValueId(ppv.id) : '';
                var fileName   = inputName + outputName;                                                                // name of file (if there was one)
                var fileOrValue = fileName ? fileName : ppv.value;
                
                var test = new Object();
                test.process_id   = ppv.process_id.toString();
                test.parameter_id = ppv.parameter_id.toString();
                test.value        = fileOrValue.toString();
                test.locus        = ppv.locus ? ppv.locus.toString() : "0";                    // could this be null?
                p.push( test );
            }
        }
        return p;
    }
}

/**
 * @class Steps is a collection class for Step
 * @property {Step[]} step step is an array of Step objects
 */
function Steps() {
    this.step = [];
    
    /** set adds a step to the step array */
    this.set = function(step){
        this.step.push(step);
    }
    
    /** getIfAnyStepHasOutputWithUniqueId returns true if there exist a output with given uniqueId, it is used when
     * creating the execution order of the steps to see if the step input has already been calculated. 
     * @returns {boolean} true if theer exist a output with given uniqueId, otherwise false
     */
    this.getIfAnyStepHasOutputWithUniqueId = function(uniqueId){
        for (var i = 0; i < this.step.length; i++){
            if ( this.step[i].getIfExistOutputWithUniqueId(uniqueId) ){
                return true;
            }
        }
        return false;
    }

    /** toJson returns a JSON representation of the the Steps object in a little special way.
     * It sets values for step, process, dependencies and process_parameter_values instead of just step.
     * @returns {object} JSON representation of the steps class
     */
    this.toJson =  function(commandConstructor){
        var json = [];
        for (var i = 0; i < this.step.length; i++){
            var object = new Object();
            object.step = i;
            object.process = this.step[i].process.toJson();
            object.dependencies = commandConstructor.dependencies.get(this.step[i].process.id).toJson();
            object.process_parameter_values = this.step[i].toJson(commandConstructor, i);
            json.push(object);
        }
        var steps = new Object();
        steps.steps = json;
        // use this to get string representation of object: JSON.stringify( json ) ;
        return steps;
    }
}

/**
 * A StepInput could be an existing file or a moved stepoutput.
 * All stepinput which is a existing file will have md5 to the md5 in the system and uniqueId = ''.
 * All stepinput which is a moved stepoutput will have md5 = '' and uniqueId = a random number (unique to the page).
 * @class StepInput is a class that describes a input to step.
 * @property {Processparametervalue} processparametervalue processparametervalue is a Processparametervalue class object
 * @property {string} md5 md5 is the hash name for file that is used, if used it means that the step input was a file from the project
 * @property {string} uniqueId uniqueId is a unique id that if has a value represents that the stepinput was a output from an other process with the id of unique id
 */
function StepInput(){
    this.processparametervalue;
    
    this.md5;           // used if it is an existing file
    this.uniqueId;      // used if does not exist and will be crated in the program

    /** set sets the stepInput properties */
    this.set = function(processparametervalue, md5, uniqueId){
        this.processparametervalue = processparametervalue;
        this.md5 = md5;
        this.uniqueId = uniqueId;
    }
    /** getFileNameWithProcessParameterValueId returns the name of the file if the searched processParameterValueId is the same as this StepInput processparametervalue
    * @returns {string} fileName The filename is: '' if the processparameterValueId did not match, 
    *                                             MD5VALUE (or hash value) of the file if it was a file and 
    *                                            'NEWFILE'+uniqueId if it was a process output */
    this.getFileNameWithProcessParameterValueId = function(processParameterValueId){
        var name = '';
        var md5      = this.md5      ? this.md5                  : '';
        var uniqueId = this.uniqueId ? 'NEWFILE' + this.uniqueId : '';
        name = this.processparametervalue.id == processParameterValueId ? (md5 + uniqueId) : '';
        return name;
    }
}

/**
 * @class StepInputs is a collection class for StepInput
 * @property {StepInput[]} stepInput stepInput is an array of StepInput objects
 */
function StepInputs() {
    this.stepInput = [];

    /** adds a Stepinput to the stepInput object */
    this.add = function(stepInput){
        this.stepInput.push(stepInput);
    }
    
    /** getWithUniqueId fetches a Stepinput object with given uniqueId
     * @returns {Stepinput|undefined} Stepinput object or undefined if no existed with given uniqueId 
     */
    this.getWithUniqueId = function(uniqueId){
        for (var i = 0; i < this.stepInput.length; i++){
            if (this.stepInput[i].uniqueId == uniqueId){
                return this.stepInput[i];
            }
        }
        return ;
    }
    /** getFileNameWithProcessParameterValueId returns the string name of the file. 
     * If it was: an existing file it will be the hash of the file.
     *            a stepoutput it will return 'NEWFILE'+uniqueId
     *           non existing it will return ''
     * @returns {string} filename '' if nonexisting, otherwise a string describing the file
     */
    this.getFileNameWithProcessParameterValueId = function(processParameterValueId){
        var str = '';
        for (var i = 0; i < this.stepOutput.length; i++){
            str += this.stepInput[i].getFileNameWithProcessParameterValueId(processParameterValueId);
        }
        return str;
    }
}

/**
 * @class StepOutput is a output of a step
 * @property {Processparametervalue} processparametervalue processparametervalue is a Processparametervalue class object
 * @property {string} uniqueId uniqueId is the unique id that this StepOutput has, all output files need to have a unique id because a process can produce different output depending of its input
 */
function StepOutput(){
    this.processparametervalue;
    this.uniqueId;      // all output files need to have a unique id because a process can produce different output depending of its input (and several of same process may be present in the dependency table)

    /** set sets the stepoutput properties */
    this.set = function(processparametervalue, uniqueId){
        this.processparametervalue = processparametervalue;
        this.uniqueId = uniqueId
    }
    /** getFileNameWithProcessParameterValueId returns the name of the file if the given Processparametervalue matches the uniqueId of this output.
     * @returns {string} filename is '' if the given processparametervalue did not match this unique id otherwise NEWFILE + uniqueId is returned 
     */
    this.getFileNameWithProcessParameterValueId = function(processParameterValueId){
        var name = '';
        var uniqueId = this.uniqueId ? 'NEWFILE' + this.uniqueId : '';
        name = this.processparametervalue.id == processParameterValueId ? uniqueId : '';
        return name;
    }
}

/**
 * @class StepOutputs is a collection class for StepOutput
 * @property {StepOutput[]} stepOutput stepOutput is an array of StepOutput objects
 */
function StepOutputs() {
    this.stepOutput = [];

    /** adds a Stepoutput to the stepOutput object */    
    this.add = function(stepOutput){
        this.stepOutput.push(stepOutput);
    }

    /** getWithUniqueId returns a Stepinput object with given uniqueId
     * @returns {Stepoutput|undefined} Stepoutput object or undefined if no existed with given uniqueId 
     */
    this.getWithUniqueId = function(uniqueId){
        for (var i = 0; i < this.stepOutput.length; i++){
            if (this.stepOutput[i].uniqueId == uniqueId){
                return this.stepOutput[i];
            }
        }
        return ;
    }

    /** getFileNameWithProcessParameterValueId returns the name of the file if the given Processparametervalue matches the uniqueId of this output.
     * @returns {string} filename is '' if the given processparametervalue did not match this unique id otherwise NEWFILE + uniqueId is returned 
     */
    this.getFileNameWithProcessParameterValueId = function(processParameterValueId){
        var str = '';
        for (var i = 0; i < this.stepOutput.length; i++){
            str += this.stepOutput[i].getFileNameWithProcessParameterValueId(processParameterValueId);
        }
        return str;
    }
}

// typical row
/*<tr>
    <td>// first td contains div with id processesUNIQUEROWID  
        <div id="processes32152">
        <input type="hidden" id="process28636" value="1">Unzip(1)</div>
    </td>
    <td>// second td contains inputs in div inputsUNIQUEROWID
        <div id="inputs32152">
            <div id="target25644" class="droppable  hasObject" ondragover="onDragOver(event)" ondrop="onDrop(event)">
                <input type="hidden" id="allowedFiletype25644" value="2">
                <div class="processDescription" onclick="showFiles('gz')">
                    TABLE_WITH_INPUT_DESCRIPTION
                </div>
                <div id="divObj27725" draggable="true" ondragstart="dragStart(event)" ondragend="onDragEnd(event)" class="draggableItem "> // draggable item
                    <button onclick="btnRemoveDragAndDropObject(commandConstructor, this);">delete</button>
                    <input type="hidden" id="fileType1234567890123456789012345678901A" value="gz">
                    <input type="hidden" id="fileId1234567890123456789012345678901A"   value="1234567890123456789012345678901A">
                    TABLE_WITH_DRAGGABLE_INPUT_DESCRIPTION
                </div>
            </div>
            <br>
        </div>
    </td>
    <td>// third td contains ouputs in div ouputsUNIQUEROWID
        <div id="outputs32152">
            <div id="div25141" draggable="true" ondragstart="dragStart(event)" ondragend="onDragEnd(event)" class="okToProcess permanent">
                <input type="hidden" id="fileType28538"            value="fsa">
                <input type="hidden" id="fileIdProcess1Output7662" value="7662">
                <input type="hidden" id="processOutputId22407"     value="1">
                TABLE_WITH_OUTPUT_DESCRIPTION
            </div>
        </div>
    </td>
    <td>
        <div id="dependencies32152"></div>
    </td>
</tr>*/

/** createExecutionTable steps through the drag and drop table and creates a valid execution order, 
 * and then returns the JSON representation of the Steps object it filled in while traversed the drag and drop table.
 * Basic ide:
 * Step through each row in the processes table, if it:
 * 1. has all inputs avaible for execution (its inputs is already calculated or already exist)
 * 2. has met all dependencies
 * it will create a execution step in the steps object
 * otherwise it will go to next row and try to do it and leave the not avaible row for later.
 * This will take maximum n(n+1)/2 times if it is possible to solve at all.
 * If it is not possible to create it will give information to user that it created a dependency loop and leave
 * it up to the user to check (should not be possible to drop an item to create a loop though so if it happens it is a error from the programmer).
 * If all is ok it will return a JSON description of the steps command. 
 * @returns {string|undefined} JSON in a string format if execution table was possible to create, otherwise undefined
 */
function createExecutionTable(commandConstructor, allowNotCompleteRows) {
    var steps       = new Steps();
    var stepOutputs = new StepOutputs();
    
    // get unique divId for each row
    var divIds = [];
    var tbl = document.getElementById('tblProcesses');
    if(tbl){
        for (var i = 0, row; row = tbl.rows[i]; i++) {              // create array of unique id's for each row (all the steps)
             var id = getRowId(row);
             if( id != 0 ){
                 divIds.push( id );
             }
        }
    }
    //alert(divIds.join(","));  // displays unique ids for each row
    
    // worst possible case you have to step through this with n(n+1)/2 number of times
    var maxTimes = (divIds.length * (divIds.length + 1))/2;
    for(var i = 0; i < maxTimes; i++){// for each process_row/table_row
        var id = divIds[i%divIds.length];
        
        var inputsDiv  = document.getElementById("inputs"  + id);     // wrapping div for inputs  on this table row
        var outputsDiv = document.getElementById("outputs" + id);     // wrapping div for outputs on this table row
        var droppables = getDroppables(inputsDiv);
        
        if(droppables){
            var nrDroppables = droppables.length;                     // nr droppables(input areas) in this table row
            var inputsExist   = [];
            var inputsCreated = [];
            
            var outputsToCreate = [];
        
            for(var d = 0; d < droppables.length; d++){// for each dropzone
                var processParameterValueInputId = getDroppableProcessParameterValueInputId(droppables[d]);
                
                var divObjects = getObjects(droppables[d]);
                // step though all objects and check if they are created(in privious step or already exist, as a file)
                if(divObjects){
                    for(var j = 0; j < divObjects.length; j++){//for each object
                        
                        var type   = getObjectType(divObjects[j]);  // returns either 'file', 'stepOutput' or 'none'
                        var fileId = getObjectFileId(divObjects[j]);// getObjectFileId, either md5 for existing files or a random number if it is a to be created file (aka stepOutput)
                        switch(type){
                            case 'file':
                              // create a StepInput 
                              var si = new StepInput();
                              si.set(commandConstructor.processparametervalues.get(processParameterValueInputId), fileId, '');
                              inputsExist.push(si);
                              break;
                            case 'stepOutput':
                                // it is something that may have been calculated before (and therefore inserted in steps)
                                if(steps.getIfAnyStepHasOutputWithUniqueId(fileId)){
                                    // this input have been calculated in a step before, if all inputs will have the status of exist or have been calculated before then insert it as next step
                                    var si = new StepInput();
                                    si.set(commandConstructor.processparametervalues.get(processParameterValueInputId), '', fileId);
                                    inputsCreated.push(si);
                                }
                              break;
                            default:
                                // type == 'none', do nothing
                        }
                    }
                }
                    
            }
            
            //alert("inputsExist: '" + inputsExist.length + "', inputsCreated: '" + inputsCreated.length + "', droppables:'" + nrDroppables + "'");
            // THIS DOES ONLY CHECK IF THE TOTAL DROPPABLE OBJECTS IS OK, USE checkAllOkToRun before running this function (which checks that all droppables has exactly one file)     
            if ( (inputsExist.length + inputsCreated.length) == nrDroppables ){
                // all inputs for this process (row) will be met, add it to steps
                
                // create a step of this row (needs process, uniqueId, inputs, outputs) and add it to steps
                /// process
                
                var process = getRowProcessFromRowUniqueRowId(commandConstructor, id);
                // replace old process project_id, person_id and type with the ones which is correct for this save
                process.project_id = commandConstructor.getLoggedInProjectId();
                process.person_id  = commandConstructor.getLoggedInPersonId();
                process.type       = commandConstructor.getProcessType();
                
                /// uniqueId == id in step == unique id of the row
                
                /// inputs
                var stepInputs = new StepOutputs();

                // first add the inputs that exist from the file system
                for(var k = 0; k < inputsExist.length; k++){
                    stepInputs.add(inputsExist[k]);
                }
                
                // then add the file that is an output from previus calculations
                for(var l = 0; l < inputsCreated.length; l++){
                    // this input is an output already calculated in steps, take its output file and use
                    stepInputs.add(inputsCreated[l]);
                }
                
                /// outputs
                var stepOutputs = new StepOutputs();
                // foreach div in outputdivs, get processoutput_id and the unique file id and store those in outputs
                var outPutDivs = outputsDiv.childNodes;
                
                for(var m = 0; m < outPutDivs.length; m++){//each div object
                
                    var processParameterValueOutputId = '';
                    var fileId = '';
                    
                    var children = outPutDivs[m].childNodes;
                    for(var n = 0; n < children.length; n++){//each div object
                        if (children[n].id && children[n].id.indexOf("processParameterValueOutputId") != -1) {    // if field is the one storing the processParameterValueOutputId
                            processParameterValueOutputId = children[n].value;
                        }
                        else if (children[n].id && children[n].id.indexOf("fileIdProcess") != -1) { // if field is the one storing the file id
                            fileId = children[n].value;
                        }
                    }
                    var so = new StepOutput();
                    so.set(commandConstructor.processparametervalues.get(processParameterValueOutputId), fileId );
                    stepOutputs.add(so);
                }
                
                var step = new Step();
                step.set(process, id, stepInputs, stepOutputs);
                steps.set(step);// add the process as a complete step.

                //have finished this row/process, remove it from the array
                divIds.splice(i%divIds.length,1);// remove the finished processed process/row
            }
            
        }
        // if all rows has been analysed, break for loop
        if(divIds.length == 0){
            //alert('no left will break');
            break;
        }
    }
    
    // if not all steps have to be calculated, add those left that failed with no output or input
    if(divIds.length !=0 && allowNotCompleteRows ){
        var maxTimes = (divIds.length * (divIds.length + 1))/2;

        for(var i = 0; i < maxTimes; i++){// for each process_row/table_row
            var id = divIds[i%divIds.length];

            var process = getRowProcessFromRowUniqueRowId(commandConstructor, id);
            // replace old process project_id, person_id and type with the ones which is correct for this save
            process.project_id = commandConstructor.getLoggedInProjectId();
            process.person_id  = commandConstructor.getLoggedInPersonId();
            process.type       = commandConstructor.getProcessType();

            /// inputs
            var stepInputs = new StepOutputs();
            /// outputs
            var stepOutputs = new StepOutputs();
            
            var step = new Step();
            step.set(process, id, stepInputs, stepOutputs);
            steps.set(step);// add the process as a complete step.
         
            divIds.splice(i%divIds.length,1);// remove the finished processed process/row
            
            if(divIds.length == 0){
                break;
            }
        }
    }
    
    // here could the steps be ready to execute
    if(divIds.length != 0 ){
        // could not calculate all the rows (loop?, loops should not be able to exist, someone must have been creative)
        showDialog('Seems to me there is some sort of problem with your input, have you made a dependency loop?\n\(Process B depends on Process As output.\n Process A has Input that is either:\n 1. An output of B\n 2. An output from an other process that depends of Process B\'s output)', "Could not create a execution order");
        return;
    }
    else{
        return JSON.stringify( steps.toJson(commandConstructor) );
    }
}
/** checkAllInputsOkToRun goes through the drag and drop table and returns true if all inputs has exactly one dragged file as input otherwise it will return false.
 * Should be called before the function createExecutionTable is called because createExecutionTable will only 
 * check that the total number of dragged files are the same amount as the amound of droppables. 
 * @returns {boolean} true if all input is ok to run, false otherwise
 */
function checkAllInputsOkToRun(){
    var tbl = document.getElementById('tblProcesses');
    if(tbl){
        var nrRowsOk = 0
        for (var i = 0, row; row = tbl.rows[i]; i++) {
            var nrInputs = 0;
            var nrInputsOk = 0;
            
            var rowId = getRowId(row);
            var droppables = [];
            droppables = getDroppables(row);
            if(droppables){
                nrInputs = droppables.length;
                
                for (var a = 0; a < droppables.length; a++) {
                    if( getNrObjectsDroppableHas(droppables[a]) == 1 ) {
                        nrInputsOk++;
                    }
                }
                
                if(nrInputs > 0 && nrInputs == nrInputsOk){ // is there any rows that could have output but no input? if so how to see the difference between them and a header row?
                    nrRowsOk++;
                }
            }
        }
        if(nrRowsOk + 1 == tbl.rows.length){ // +1 for header
            //alert('all rows in ok, can submit');
            return true;
        }
    }
    return false;
}

/** removeAllNotValidOutputs that goes through every row in the drag and drop table and if a row's input is not ok remove that row's output from all other rows.
 * If any dragged items was removed it calls it self to be sure all rows will be fine in the end, after all rows are ok, it will update the classes on the droppables to get the correct color code. 
 */
function removeAllNotValidOutputs(commandConstructor){
    var tbl = document.getElementById('tblProcesses');
    if(tbl){
        var nrRowsOk = 0
        for (var i = 0, row; row = tbl.rows[i]; i++) {
            var nrInputs = 0;
            var nrInputsOk = 0;
            
            var rowId = getRowId(row);
            var droppables = [];
            droppables = getDroppables(row);
            if(droppables){
                nrInputs = droppables.length;
                
                for (var a = 0; a < droppables.length; a++) {
                    if( getNrObjectsDroppableHas(droppables[a]) == 1 ) {
                        nrInputsOk++;
                    }
                }
                
                if(nrInputs > 0 && nrInputs == nrInputsOk){ // is there any rows that could have output but no input? if so how to see the difference between them and a header row?
                    nrRowsOk++;
                }
                else{
                    // row was not ok, get all dragged items that uses this output and remove them
                    var divOutputs = document.getElementById('outputs' + rowId);// get output div
                    var processParameterValueIds = [];
                    var inputs = divOutputs.getElementsByTagName('input');
                    for(var b = 0; b < inputs.length; b++) {
                        if( inputs[b].id.indexOf("processParameterValueOutputId") != -1 ){
                            processParameterValueIds.push(inputs[b].value); // store the processParameterValueIds
                        }
                    }
                    // get number of items before the call and after the call, if any objects removed, call the cleanup function again
                    var draggedItemsBeforeRemoval = getNrDraggedItems(tbl);
                    // get tables all droppables and remove all that has an hidden input with name like processParameterValueOutputId that has a value of any one int the array
                    removeAllDraggedItemsWithProcessParameterValue(commandConstructor, tbl, processParameterValueIds);// this will update the droppables classes when an item is removed
                    var draggedItemsAfterRemoval = getNrDraggedItems(tbl);
                    
                    if( draggedItemsBeforeRemoval != draggedItemsAfterRemoval){
                        // after removal of an object, call this function again so we know that all rows have been checked
                        removeAllNotValidOutputs(commandConstructor);
                        return;// avoid the rest of the rows to be checked
                    }
                }
            }
        }
    }
}

/** getNrDraggedItems returns the number of droppables (items that has css class droppable) the table has 
 * @returns {numeric} nr of dragged objects the table has
 */
function getNrDraggedItems(tbl){
    var nrObjects = 0;
    for (var i = 0, row; row = tbl.rows[i]; i++) {
        var droppables = [];
        droppables = getDroppables(row);
        if(droppables){
            nrObjects += droppables.length;
        }
    }
    return nrObjects;
}

/** removeAllDraggedItemsWithProcessParameterValue removes all dragged items that has 
 * a processParameterValueId in the processParameterValueIds array 
 */
function removeAllDraggedItemsWithProcessParameterValue(commandConstructor, tbl, processParameterValueIds){
    for (var i = 0, row; row = tbl.rows[i]; i++) {
        var droppables = [];
        droppables = getDroppables(row);
        if(droppables){
            for (var a = 0; a < droppables.length; a++) {
                var droppable = droppables[a];
                
                var inputs = droppable.getElementsByTagName('input');
                for(var b = 0; b < inputs.length; b++) {
                    if( inputs[b].id.indexOf("processParameterValueOutputId") != -1 ){
                        for(var c = 0; c < processParameterValueIds.length; c++){
                            if(inputs[b].value == processParameterValueIds[c]){
                                // get object div
                                var divObject = getClosestParentDiv(inputs[b]);
                                removeDragAndDropObject(commandConstructor, divObject);
                            }
                        }
                    }
                }
            }
        }
    }
}

/** createRun checks if all inputs are ok and if they are return the JSON describing the Steps it could be run in. 
 * If not all is ok, it will show a dialog telling the user that not all is ok and return '' 
 * @returns {string} JSON describing the steps it could run the commands in, if not ok returns ''
 */
function createRun(commandConstructor){
    if(checkAllInputsOkToRun()){
        var allowNotCompleteRows = false;
        var jsonText = createExecutionTable(commandConstructor, allowNotCompleteRows);
        if( !jsonText ){
            // dependency problem (inputs ok though)
            return '';
        }
        else{
            // valid json
            return jsonText;
        }
    }
    else{
        showDialog("I'm sorry but I feel something is amiss (double check that no inputs is red).", 'All fields are not ready');
    }
    return '';
}

/** showFiles will hide all files that is not of fileType from the client file list. If fileType == all, all files will be shown. */
function showFiles(commandConstructor, fileType){
    var divFiles = document.getElementById('projectFiles');
    var divFile = getDraggables(divFiles);
    if(divFile){
        for(var i = 0; i < divFile.length; i++){
            if(fileType == 'all' || fileType == '*'){
                removeClasses(divFile[i], ["hidden"])
            }
            else{
                var existingFileTypeId = getDraggedItemsFileType(divFile[i]); // actually this is the existing files filetype, but it works in the same as when you try to get dragged items filetype
                // see if the existing file has the same fileTypeId as the droppable or it has the droppable as a sybtype (parent in filetypes --> ok to drop)
                isFiletypeATypeOrSubtypeOfFiletype(commandConstructor, existingFileTypeId, fileType) ? removeClasses(divFile[i], ["hidden"]) : addClasses(divFile[i], ["hidden"]);
            }
        }
    }
    else{
        divFiles.innerHTML = "I did not find any files when loading the page, refresh the page if you know there should exist some because it has been added.";
    }
}

/** showParameterDialog will show a dialog for a process and all its command parameters so the client can decide what parameters should be used. */
function showParameterDialog(commandConstructor, process_id){
    var process                = commandConstructor.processes.get(process_id);                          // get process
    var parameters             = commandConstructor.parameters.getWithCommandId(process.command_id);    // and all of its command parameters
    var processParameterValues = commandConstructor.processparametervalues.getWithProcessId(process_id);// and all parameters existing values 
    var divProcessParametersId = 'dialog' + process_id;
    var r = '<div id="' + divProcessParametersId + '">\
                <h3 class="left">Process</h4>\
                <table class="dialogTable left">\
                    <thead>\
                        <tr>\
                            <th>Name</th>\
                            <th>Description</th>\
                        </tr>\
                    </thead>\
                    <tbody>\
                        <tr>\
                            <td><input type="text" value="' + process.iname       + '" onkeyup="handleProcessNameChanged(event, this, '        + commandConstructor.name + ',\''+ process.id  + '\')"/></td>\
                            <td><textarea onkeyup="handleProcessDescriptionChanged(event, this, ' + commandConstructor.name + ',\''+ process.id  + '\')" >' + process.description +'</textarea></td>\
                        </tr>\
                    </tbody>\
                </table>\
                <h3 class="left">Parameters</h4>\
                <table class="dialogTable">\
                    <thead>\
                        <tr>\
                            <th>Use</th>\
                            <th>Mandatory</th>\
                            <th>Name</th>\
                            <th>Template</th>\
                            <th>Nr parameters</th>\
                            <th>Value</th>\
                        </tr>\
                    </thead>\
                    <tbody>';
    parameters.parameter.sort(parameters.compareLocus);// sort the parameters so they show up in the correct order for the user
    for( var i = 0; i < parameters.parameter.length; i++){
        var parameter                       = parameters.parameter[i];
        var parameterIsMandatory            = parameter.is_mandatory == true ? true : false;
        var parameterProcessParameterValues = processParameterValues.getWithParameterId(parameter.id);
        var hasProcessParameterValue        = parameterProcessParameterValues.processparametervalue.length > 0 ? true : false;
        parameterProcessParameterValues.processparametervalue.sort(parameterProcessParameterValues.processparametervalue.compareLocus);// sort this parameters values
        
        var divInputsId   = createUniqueId('divInputs');
        var hiParameterId = createUniqueId('hiParameterId');
        var hiProcessId   = createUniqueId('hiProcessId');
        var parameterHasValue = parameterProcessParameterValues.getWithParameterId(parameter.id).processparametervalue.length ? true : false;// get if parameter is in use (ie has a value)
        // if the parameter does not have a value it should not have a add more button, because if it does not have a value it is not in use (in the command)
        var inputs = createInputsForParameter(commandConstructor, parameterHasValue, parameter, divInputsId, parameterProcessParameterValues);
        
        var cbParameter = parameterIsMandatory ? 'checked="checked" disabled="disabled "' : hasProcessParameterValue ? 'checked="checked"' : '';
        var cbMandatory = parameterIsMandatory ? 'checked="checked"' : '';
        
        // rewrite min_items/max_items to a more understandible description
        var nrInputsAllowed;
        if( parameter.max_items == 0 && parameter.min_items == 0 ){
            nrInputsAllowed = 'none';
        }
        else if (parameter.max_items < parameter.min_items){
            nrInputsAllowed = 'at least ' + parameter.min_items;
        }
        else if (parameter.max_items == parameter.min_items ){
            nrInputsAllowed = parameter.max_items;
        }
        else {
            nrInputsAllowed = 'between ' + parameter.min_items + ' and ' + parameter.max_items; // min_items = 2, max_items = 5 --> between 2 and 5 inputs
        }
    

        
        r +=           '<tr>\
                            <td>\
                                <input type="checkbox" id="cbUse' + parameter.id + '"' + cbParameter + ' onclick="handleCheckboxUseParameterClicked(' + commandConstructor.name + ', this);" />\
                                <input type="hidden"   id="' + hiParameterId + '" value="' + parameter.id + '"               />\
                                <input type="hidden"   id="' + hiProcessId   + '" value="' + process_id   + '"               />\
                            </td>\
                            <td><input type="checkbox" id="cbMandatory" '              + cbMandatory + ' disabled="disabled" /></td>\
                            <td>' + parameter.iname     + '</td>\
                            <td>' + parameter.template  + '</td>\
                            <td title="min_items=' + parameter.min_items + ', max_items=' + parameter.max_items + '">' + nrInputsAllowed + '</td>\
                            <td><div id="' + divInputsId + '">' + inputs + '</div></td>\
                        </tr>';
    }
    r +=           '</tbody>\
                </table>\
           </div>';
  
   // call jquery show dialog window
   showCommandParameters(r);
}

/** updateProcessParametervalues updates the processParameterValues a process parameter has to the right number of values.
 * If it should not have any it will remove existing ones and if it should have values it will add so many it lacks to fulfill 
 * its minimum (described by the parameters min_items and max_items fields).
 * updateProcessParametervalues is usually called when you add or remove a parameter for a command in the parameterdialog. 
 */
function updateProcessParametervalues(commandConstructor, shouldHaveValues, process, parameter, existingParameterProcessParameterValues){
    if(shouldHaveValues){
        // add values that it needs to satisfy minimum number of values
        var existingNrValues = existingParameterProcessParameterValues.processparametervalue.length;    // nr existing values
        var minNrValues      = parameter.getMinNumberItems();                                           // get min number of parameter input items
        var maxLocus = existingParameterProcessParameterValues.getMaxLocus();                           // maximum locus of the values

        var createdPPVIds = []; // array of created ids, they will be in the form of processParameterValueIdRAND, the value will be the real id
        
        for(var j=0; j < minNrValues - existingNrValues; j++){                                          // create remaining values for min number of values to be set
            var tmpProcessParameterValue = new Processparametervalue();
            
            var ppvId;
            var idOk = false;
            while( !idOk ){
                idOk = true;
                ppvId = commandConstructor.createDummyProcessParameterValueId(); // get value that is unique in the commandConstructor (and indirectly the webpage because it uses createUniqueId function)
                
                // check it against already created values
                if( createdPPVIds.indexOf(ppvId) != -1){ 
                     idOk = false;            // existed
                }
                else{
                    createdPPVIds.push(ppvId);// is unique
                }
            }
            tmpProcessParameterValue.set(ppvId, process.id, parameter.id, '', ++maxLocus);// on the first run it contains the max value of the existing values
                                                                                          // we want to increment it by one for each added value
            commandConstructor.processparametervalues.add(tmpProcessParameterValue);      // add new values to the main object..
        }
        
        // add empty value for those parameters that has a min_items and max_items value of 0
        // (all parameters that are in used have a processParameterValue, those that has min_items == 0 and max_items == 0 should show 
        // no inputs but still have a empty value)
        if(parameter.max_items == 0 && parameter.min_items == 0 && existingNrValues != 1 ){
            // create id
            var ppvId;
            var idOk = false;
            while( !idOk ){
                idOk = true;
                ppvId = commandConstructor.createDummyProcessParameterValueId(); // get value that is unique in the commandConstructor (and indirectly the webpage because it uses createUniqueId function)
                // check it against already created values
                if( createdPPVIds.indexOf(ppvId) != -1){ 
                     idOk = false;            // existed
                }
                else{
                    createdPPVIds.push(ppvId);// is unique
                }
            }
            var ppv = new Processparametervalue();
            ppv.set(ppvId, process.id, parameter.id, '', 0);
            commandConstructor.processparametervalues.add(ppv);
        }
        
    }
    else{
        // remove the values
        for(var i=0; i < existingParameterProcessParameterValues.processparametervalue.length; i++){
            commandConstructor.processparametervalues.remove(existingParameterProcessParameterValues.processparametervalue[i]);
        }
    }
}

/** createInputsForParameter creates html for a input to be inserted into the parameter dialog 
 * @returns {string} HTML for the intputs in the parameter
 */
function createInputsForParameter(commandConstructor, areUsed, parameter, divInputsId, parameterProcessParameterValues){
    
    // how many input fields are allowed and how many should be shown?
    var nrInputsAllowed;
    if( parameter.max_items == 0 && parameter.min_items == 0 ){
        nrInputsAllowed = 'none';
    }
    else if (parameter.max_items < parameter.min_items){
        nrInputsAllowed = 'infinite';
    }
    else if (parameter.max_items == parameter.min_items ){
        nrInputsAllowed = 'fixed';
    }
    else {
        nrInputsAllowed = 'range'; // min_items = 2, max_items = 5 --> between 2 and 5 inputs
    }
    
    var inputProcessParameterValuePrefix = 'processParameterValueId';
    var nrValues = parameterProcessParameterValues.processparametervalue.length;
    var inputs = [];
    if (nrInputsAllowed != 'none'){
        for(var i=0; i < nrValues; i++){
            var pppv = parameterProcessParameterValues.processparametervalue[i];
            var div = createNewProcessParameterValueDiv(commandConstructor, pppv, inputProcessParameterValuePrefix + pppv.id);
            inputs.push(div.outerHTML);
        }
        // here minimum number of inputs exist, add a add button if you are allowed to add more values then exist and the parameter is used
        if(areUsed){
            if( canAddOneMoreParmeterValue(inputs.length, parameter) ){
                var btnAdd = createNewParameterValueButton(commandConstructor);
                inputs.push(btnAdd.outerHTML);
            }
        }
    }
    return inputs.join('');

}

/** createNewProcessparameterValueDiv returns HTML for the processParameterValue, 
 * if processParameterValue is left empty it is assumed that it is a new ProcessParameterValueDiv that should be created 
 * @returns {string} HTML for a processParameterValue which outer element is a div
 */
function createNewProcessParameterValueDiv(commandConstructor, processParameterValue, inputProcessParameterValueId){
    var parameter = commandConstructor.parameters.get(processParameterValue.parameter_id);
    
    /*  if file
        <div id="fileWithProcessParameterValueIdID/newFileIdRAND">
            <input type="hidden" value="">
            file
            <img class="deleteInputButton src="DEL_NO_FOCUS_URL" onmouseover="DEL_FOCUS_URL" onmouseout="DEL_NO_FOCUS_URL" onclick="btnRemoveInputFromInputs" title="Delete input from command" />
        </div>
        
        if input
        <div id="inputWithProcessParameterValueIdID/newInputIdRAND">
            <input type="text" value="INPUTVALUE/''"/>
            <img class="deleteInputButton src="DEL_NO_FOCUS_URL" onmouseover="DEL_FOCUS_URL" onmouseout="DEL_NO_FOCUS_URL" onclick="btnRemoveInputFromInputs" title="Delete input from command" />
        </div>
    */
    var div       = document.createElement("div");
    div.setAttribute('class', 'divInputParameter');
        
    div.innerHTML = '<input type="hidden" id="' + inputProcessParameterValueId + '" value="' + processParameterValue.id + '"/>';
    
    // get if input is a file or value 
    var parameterType = commandConstructor.parametertypes.get(parameter.parameter_type_id);
    var isFile        = parameterType.file_type_id > 0 ? true : false;
    
    var divId;
    
    if(isFile){
        divId          = processParameterValue ? 'fileWithProcessParameterValueId' + processParameterValue.id : createUniqueId('newFileId');
        div.innerHTML += 'file';
    }
    else{
        divId          = processParameterValue ? 'inputWithProcessParameterValueId' + processParameterValue.id : createUniqueId('newInputId');
        var inputValue = processParameterValue ? processParameterValue.value : '';

        div.innerHTML += '<input type="text" value="' + inputValue + '" onkeyup="handleInputValueChanged(event, this, ' + commandConstructor.name + ',\''+ inputProcessParameterValueId  + '\')"/>';
    }
    
    div.setAttribute('id', divId);
    var btnRemoveId = createUniqueId('btnRemoveThisParameterValue');
    
    div.innerHTML += "<img class=\"deleteInputButton\"\
                             src=" + document.getElementById('del_no_focus_url').value + " \
                             onmouseover=\"this.src='" + document.getElementById('del_focus_url').value    + "';highlightClosestParentOfType(this, 'div')\" \
                             onmouseout=\"this.src='"  + document.getElementById('del_no_focus_url').value + "';unhighlightClosestParentOfType(this, 'div')\" \
                             onclick=\"btnRemoveInputFromInputs(" + commandConstructor.name + ", this)\"\
                             title=\"Delete input from command\"\
                             />";
    return div;
}

/** createNewparameterValueButton creates HTML for a add button that is supposed to add a new input to a parameter 
 * @returns {object} HTML for a add button to a parameter
 */
function createNewParameterValueButton(commandConstructor){
    var btnAdd = document.createElement("button");
    var id = createUniqueId('btnAddOneMoreInput');
    btnAdd.setAttribute('id', id);
    btnAdd.setAttribute('onclick', 'btnAddInputToInputs(' + commandConstructor.name + ', this)');
    btnAdd.innerHTML = "Add extra input";
    return btnAdd;
}

/** handleCheckboxUseParameterClicked calls analyseAction updateParameterUsage */
function handleCheckboxUseParameterClicked(commandConstructor, checkBox){
    analyseAction( 'updateParameterUsage', {'commandConstructor': commandConstructor, 'object': checkBox } );
}

/** updateParameterUsage creates HTML for the parameter inputs that the checkbox belongs to 
 * and inserts them to the inputsDiv, if the parameter was a file (has a parameterType of input or output)
 * it will return true which should result in a refresh on the drag and drop table
 * @returns {boolean} true if after function call it needs to refresh the drag and drop table otherwise false
 */
function updateParameterUsage(commandConstructor, checkBox){

    // get if checkbox is checked or not
    var cbChecked = checkBox.checked;
    
    // get rowNode
    var row = getClosestParentRow(checkBox);

    // get divInputsId, it has the form of divInputsRAND
    var divInputsId;
    var divs = row.getElementsByTagName('div');
    for(var i = 0; i < divs.length; i++) {
        if( divs[i].id.indexOf("divInputs") != -1 ){
            divInputsId = divs[i].id;
            break;
        }
    }
    
    // get processId and parameterId
    var processId, parameterId;
    var inputs = row.getElementsByTagName('input');
    for(var i = 0; i < inputs.length; i++) {
        // get processId
        if( inputs[i].id.indexOf("hiProcessId") != -1 ){
            processId = inputs[i].value;
        }
        // get parameterId
        if( inputs[i].id.indexOf("hiParameterId") != -1 ){
            parameterId = inputs[i].value;
        }
    }
    
    var process   = commandConstructor.processes.get(processId);
    var parameter = commandConstructor.parameters.get(parameterId);
    // if the checkbox was an parameter with filetype of input or output, it must trigger a refresh drag and drop table
    var parameterType = commandConstructor.parametertypes.get(parameter.parameter_type_id);
    var needToRefreshDragAndDropTables = parameterType.iname == 'input' || parameterType.iname == 'output' ? true : false;
    var divInputs = document.getElementById(divInputsId);

    updateProcessParametervalues(commandConstructor, cbChecked, process, parameter, commandConstructor.processparametervalues.getWithProcessIdAndParameterId(processId, parameter.id) );
    // create html inputs for the parameter
    var newInputs = createInputsForParameter(commandConstructor, cbChecked, parameter, divInputs.id, commandConstructor.processparametervalues.getWithProcessIdAndParameterId(processId, parameter.id) );
    // add html
    divInputs.innerHTML = newInputs;
    
    return needToRefreshDragAndDropTables;
}

/** handleInputValueChanged updates the commandConstructors processparametervalue that the input are associated to */
function handleInputValueChanged(event, input, commandConstructor, hiProcessParameterValueId){
    var hiId = document.getElementById(hiProcessParameterValueId);
    var ppv = commandConstructor.processparametervalues.get(hiId.value);
    ppv.value = input.value;
}

/** handleProcessNameChanged calls the analyseAction function with 'changeProcessName' that will update the process iname */
function handleProcessNameChanged(event, input, commandConstructor, processId){
    analyseAction( 'changeProcessName', {'commandConstructor': commandConstructor, 'object': input, 'processId': processId } );
}

/** handleProcessDescriptionChanged calls the analyseAction function with 'changeProcessDescription' that will update the process description */
function handleProcessDescriptionChanged(event, input, commandConstructor, processId){
    analyseAction( 'changeProcessDescription', {'commandConstructor': commandConstructor, 'object': input, 'processId': processId } );
}

/** btnRemoveDragAndDropObject calls the analyseAction function with 'removeDragAndDropObject' that will remove a object from the drag and drop table */
function btnRemoveDragAndDropObject(commandConstructor, btn){
    analyseAction( 'removeDragAndDropObject', {'commandConstructor': commandConstructor, 'object': btn } );
}

/** removeDragAndDropObject removes a drag and drop object from the drag and drop and also removes its dependencies if it should be removed */
function removeDragAndDropObject(commandConstructor, divObject){
    if( isDraggedItemAnOutputFromAProcess(divObject) ){ // it is a stepOutPut, or a object that has dependencies

        // 1. get processId for this object (the parent in the dependency)
        // get processParameterValueId from hidden field in the div
        var inputs = divObject.getElementsByTagName('input');
        var processParameterValueId;
        for(var i = 0; i < inputs.length; i++) {
            if( inputs[i].id.indexOf("processParameterValue") != -1 ){
                processParameterValueId = inputs[i].value;
                break;
            }
        }
        var parentProcessId = commandConstructor.processparametervalues.get(processParameterValueId).process_id;
        
        // 2. count nr of objects that has that process_id
        var divTarget = getClosestParentDiv(divObject); // dropzone for object
        var divInputs = getClosestParentDiv(divTarget); // all inputs

        var allInputs = divInputs.getElementsByTagName('input');
        var nrObjectsWithThatProcessId = 0;
        for(var i = 0; i < allInputs.length; i++) {
            if( allInputs[i].id.indexOf("processParameterValue") != -1 ){
                nrObjectsWithThatProcessId += commandConstructor.processparametervalues.get(allInputs[i].value).process_id == parentProcessId ? 1 : 0;
            }
        }
        if(nrObjectsWithThatProcessId <= 1){// should nerver be less then 1 (that would mean that our get processparametervalues.get did not work)
            // 3. last process dependency removed from this row, remove the dependency
            var processId;
            var row = getClosestParentRow(divObject);
            var inputs = row.getElementsByTagName('input');
            for(var i = 0; i < inputs.length; i++) {
                // get processId
                if( inputs[i].id.indexOf("hiProcessId") != -1 ){
                    processId = inputs[i].value;
                }
            }   
            // remove dependency
            commandConstructor.dependencies.remove(commandConstructor.dependencies.getWithProcessIdAndParentId(processId, parentProcessId));
        }
        else{
            // there exist dependencies still, do not remove the dependency
        }
    }
    // remove the div
    var parent = divObject.parentNode;
    parent.removeChild(divObject);
}

/** highlightClosestParentOfType gets closest parent of type highlighObjectType and adds the class 'highlight' to it */
function highlightClosestParentOfType(id, highlightObjectType){
    var obj = getClosestParent(id, highlightObjectType);   // get highlightObject (could be div, tr, li,..
    obj.classList.add("highlight");
}

/** unhighlightClosestParentOfType gets the closest parent for the node of the type of highlightObjectType and removes the class 'highlight' from it */
function unhighlightClosestParentOfType(id, highlightObjectType){
    var obj = getClosestParent(id, highlightObjectType);   // get type (could be 'div, tr, li,..
    obj.classList.remove("highlight");
}

/** btnRemoveProcess calls the analyseAction with 'removeProcess' which will remove the process from the drag and drop table*/
function btnRemoveProcess(commandConstructor, btn, processId){
    analyseAction( 'removeProcess', {'commandConstructor': commandConstructor, 'object': btn, 'processId': processId } );
}

/** removeProcess removes a process from the drag and drop table
 * it will first remove the outputs, then the row, then the data and last do a update
 * you can not remove the data before the outputs because when you remove all the draggedItmesWithProcessparameterValue 
 * it calls removeDragAndDropObject that checks for dependencies of the removed drag and drop 
 */
function removeProcess(commandConstructor, btn, processId){
    // get the outputs for this row, remove those from the drag and drop table
    var row = getClosestParentRow(btn);   // get row
    var tbl = getClosestParentTable(row); // get table
    var rowId = getRowId(row);
    var divOutputs = document.getElementById('outputs' + rowId);// get output div
    var processParameterValueIds = [];
    var inputs = divOutputs.getElementsByTagName('input');
    for(var b = 0; b < inputs.length; b++) {
        if( inputs[b].id.indexOf("processParameterValueOutputId") != -1 ){
            processParameterValueIds.push(inputs[b].value); // store the processParameterValueIds
        }
    }
    // get tables all droppables and remove all that has an hidden input with name like processParameterValueOutputId that has a value that exist in the array
    removeAllDraggedItemsWithProcessParameterValue(commandConstructor, tbl, processParameterValueIds);
    
    // remove the row
    var parent = row.parentNode;
    parent.removeChild(row);

    // remove the data and its dependencies
    commandConstructor.removeProcessWithValues(processId);
}

/** btnRemoveInputFromInputs calls the analyseAction with 'removeInputFromInputs' which will remove a input from the parameter dialog */
function btnRemoveInputFromInputs(commandConstructor, clickedButton){
    analyseAction( 'removeInputFromInputs', {'commandConstructor': commandConstructor, 'object': clickedButton } );
}

/** removeInputFromInputs is called when deleting a input from the parameter dialog.
 * What will happen is that the input (processparametervalue) is removed and after that it will check if the amount of processparametervalues are ok.
 * If not it will add new processparametervalues one at the time until it is ok. After the right amount of processparameterinput exist it will create 
 * the HTML for the inputs and replace those that existed before.
 * It is important to refresh the 'tableProcesses' (drag and drop table) after removeInputFromInputs has been called because the processparametervalue 
 * has been removed in the commandconstructor but not been removed in the draganddroptable (there is a hidden with id processParameterValueInputIdRAND
 * that has the old value after the delete).
 * Because of this "youhavetorefreshdraganddroptableafterdelete" the commandconstructor function commandConstructor.updateProcessParameterValuesFromTable
 * have to be able to handle when a input does not exist in the commandconstructor but it does in the draganddroptable.
 */
function removeInputFromInputs(commandConstructor, clickedButton){
 
    // get divInputs
    var divInput  = getClosestParentDiv(clickedButton);
    var divInputs = getClosestParentDiv(divInput);
 
    // get processParameterValueId from hidden field in the div
    var inputs = divInput.getElementsByTagName('input');
    var processParameterValueId;
    for(var i = 0; i < inputs.length; i++) {
        if( inputs[i].id.indexOf("processParameterValueId") != -1 ){
            processParameterValueId = inputs[i].value;
            break;
        }
    }

    // get parameter from processParameterValueId
    var processParameterValue = commandConstructor.processparametervalues.get(processParameterValueId);
    var parameter             = commandConstructor.parameters.get(processParameterValue.parameter_id);
    var processId = processParameterValue.process_id;

    // remove it from the commandConstructor
    commandConstructor.processparametervalues.remove(processParameterValue);

    // update the processParameterValues which will fix if to few values exist by adding new ones
    var process = commandConstructor.processes.get(processId);
    updateProcessParametervalues(commandConstructor, true, process, parameter, commandConstructor.processparametervalues.getWithProcessIdAndParameterId(processId, parameter.id) );
    // create html inputs for the parameter
    var newInputs = createInputsForParameter(commandConstructor, true, parameter, divInputs.id, commandConstructor.processparametervalues.getWithProcessIdAndParameterId(processId, parameter.id) );
    // add html
    divInputs.innerHTML = newInputs;
}

/** btnAddInputToInputs calls the analyseAction with 'addInputToInputs' which will add a input to the inputs for a parameter in the parameter dialog */
function btnAddInputToInputs(commandConstructor, clickedButton){
    analyseAction( 'addInputToInputs', {'commandConstructor': commandConstructor, 'object': clickedButton } );
}
 
/** addInputToInputs adds a input to the inputs for a parameter in the parameter dialog.
 * addInputToInputs relies on to that the button is on the same row in the table as the inputs, 
 * if you want to change this you have to add processId and parameterId to the function. 
 */
function addInputToInputs(commandConstructor, clickedButton){
    
    // get divInputs
    var divInputs = getClosestParentDiv(clickedButton);
    
    // remove add btn, always remove the button and add it later if it allowes one more
    divInputs.removeChild(clickedButton);

    // check if you can add one more value in the commandConstructor
    // first I get the process and parameter id from the row
    var processId, parameterId;
    var row = getClosestParentRow(divInputs);
    var inputs = row.getElementsByTagName('input');
    for(var i = 0; i < inputs.length; i++) {
        // get processId
        if( inputs[i].id.indexOf("hiProcessId") != -1 ){
            processId = inputs[i].value;
        }
        // get parameterId
        if( inputs[i].id.indexOf("hiParameterId") != -1 ){
            parameterId = inputs[i].value;
        }
    }
    var parameter                       = commandConstructor.parameters.get(parameterId);
    
    var processParameterValues          = commandConstructor.processparametervalues.getWithProcessId(processId);
    var parameterProcessParameterValues = processParameterValues.getWithParameterId(parameter.id);

    // get Nr parameters in
    if( canAddOneMoreParmeterValue(parameterProcessParameterValues.processparametervalue.length, parameter) ){
        var inputProcessParameterValuePrefix = 'processParameterValueId';
        var processParameterValue = createNewProcessParameterValue(commandConstructor, divInputs, inputProcessParameterValuePrefix);
        commandConstructor.processparametervalues.add(processParameterValue);
        // add new item input to divInputs
        addInputDivToInputs(commandConstructor, divInputs, parameter, processParameterValue,inputProcessParameterValuePrefix);
    }

    
    // get number of inputs
    var nr = divInputs.getElementsByTagName('div').length;
    
    // get number of values..
    var nrValues = ((commandConstructor.processparametervalues.getWithProcessId(processId)).getWithParameterId(parameter.id)).processparametervalue.length;
    
    // add add btn if more inputs are allowed
    if( canAddOneMoreParmeterValue(nr, parameter) ){
        divInputs.appendChild( createNewParameterValueButton(commandConstructor) );
    }
}

/** addInputDivToInputs adds a inputDiv to the inputsDiv for a parameter in the parameter dialog */
function addInputDivToInputs(commandConstructor, divInputs, parameter, processParameterValue,inputProcessParameterValuePrefix){

    // get number of inputs
    var nr = divInputs.getElementsByTagName('div').length;// each value is enclosed in a div which is enclosed in a div

    // create processParameterValue
    var inputId = inputProcessParameterValuePrefix + processParameterValue.id;
    
    // add div        
    var div = createNewProcessParameterValueDiv(commandConstructor, processParameterValue, inputId);
    divInputs.appendChild(div);
}

/** createNewProcessParameterValue creates a new processParameterValue for a given divInputsNode.
 * The locus is going to be larger than any other existing processParameterValue.locus but 
 * it should be changed on server to avoid locus order gaps (1,5,67..).
 */
function createNewProcessParameterValue(commandConstructor, divInputsNode, inputProcessParameterValuePrefix){//divInputsNode must exist
    // processparameterValue demands  process_id, parameter_id, value, locus
    // process_id   is going to be retrieved from the rows hidden hiProcessId
    // parameter_id is going to be retrieved from the rows hidden hiParameterId
    // value is going to be '', 
    // locus is going to be checked by existing values, first get the ppvids and then look up their locus, then add one to
    // remember to change locus on server side (so it will be incremented order with low numbers)
    
    // create id that is unique as id on the page as well as in the ProcessParameterValue object
    var id, processId, parameterId, value, locus;
    value = '';

    var idOk = false;
    while( !idOk ){
        idOk = true;
        // get value that is unique in the commandConstructor (and indirectly the webpage because it uses createUniqueId function)
        id = commandConstructor.createDummyProcessParameterValueId(); 
        
        if( document.getElementById(inputProcessParameterValuePrefix + id != null) ){// check the value with the prefix (which is what it is going to have in the page)
            idOk = false;
        }
    }

    var maxLocus = 0;
    var row = getClosestParentRow(divInputsNode);
    var inputs = row.getElementsByTagName('input');
    for(var i = 0; i < inputs.length; i++) {
        // get processId
        if( inputs[i].id.indexOf("hiProcessId") != -1 ){
            processId = inputs[i].value;
        }
        // get parameterId
        if( inputs[i].id.indexOf("hiParameterId") != -1 ){
            parameterId = inputs[i].value;
        }
        // get locus
        if( inputs[i].id.indexOf("processParameterValueId") != -1 ){
            var processParameterId = inputs[i].value;
            var ppv = commandConstructor.processparametervalues.get(processParameterId);
            maxLocus = ppv.locus && ppv.locus > maxLocus ? ppv.locus : maxLocus;
        }
    }
    locus = maxLocus;

    var processParameterValue = new Processparametervalue();
    processParameterValue.set(id, processId, parameterId, value, locus);
    return processParameterValue;
}

/** canAddOneMoreParameterValue checks if the parameter can add one more parameter value given the existing items. 
 * Min and max values in parameter describes the number of possible parameters: none, infinite, fixed and range
 * (When no values are allowed max_items == 0 and min_items == 0, when infinite values are allowed min_items > max_items.) 
 * @returns {boolean} true if parameter can add one or more value, false if it can not add one more value
 */
function canAddOneMoreParmeterValue(existingItems, parameter){
    var min_items = parameter.min_items;
    var max_items = parameter.max_items;

    // man and max values could describe: none, infinite, fixed, range
    // if none max_items == 0 and min_items == 0, if infinite min_items > max_items
    if(min_items == 0 && max_items == 0){// none allowed
        return false;
    }
    else if ( min_items > max_items){    // infinite number
        return true;
    }
    else if (max_items == min_items ){   // exact number of parameters
        return existingItems < max_items ?  true : false; // must have been an error or could you remove an parameter even though the numbers had to be that amount?
    }
    else {                               // range
        var newNr = existingItems + 1;
        return    ( newNr <= max_items ) && ( newNr >= min_items ) ? true : false;
    }
}

/** getHiddenInputFromProcessId returns the input that stores the processId for the row.
 * Its id contains the string 'hiProcessId' and if none was found in the table will return false. 
 * @returns {object|boolean} hidden input which have a id that contains 'hiProcessId' or false if none was found
 */
function getHiddenInputFromProcessId(processId, tblId){
    var tbl = document.getElementById(tblId);
    if(tbl){
        for (var i = 0, row; row = tbl.rows[i]; i++) {
             var id = getRowId(row);
             if( id != 0 ){// not working on header row
                var inputs = row.getElementsByTagName('input');
                for(var j = 0; j < inputs.length; j++) {
                    // get processId
                    if( inputs[j].id.indexOf("hiProcessId") != -1  && inputs[j].value == processId){
                        return inputs[j];
                    }
                }
             }
        }
    }
    return false;
}


/** rereshDragAndDropTable calls the analyseAction function with the value 'refreshDragAndDropTable'
 * that will recreate the HTML for the dragAndDropTable from the commandConstructor and replace the old HTML with the recreated HTML.
 */
function refreshDragAndDropTable(commandConstructor){
    analyseAction( 'refreshDragAndDropTable', {'commandConstructor': commandConstructor} );
}

/** getLastNumber returns last number in the string, null if no exist 
 * @returns {string|null} last number in the string from the end and null if no exist 
 */
function getLastNumber(str) {
    if(str == null){
        return null;
    }
    var result = null;
    // pattern for last digit: (\d+)"*$
    var regExp = new RegExp( /(\d+)$/ );
    // test if there is a match
    if( regExp.test(str) ){
        result = regExp.exec(str)[0];//[0] returns the first match
    }
    return result;
}

/** Array.prototype.unique removes all duplicate strings from an array of strings.
 * It uses filter which may not be supported in all browsers. 
 * @returns {string[]} where all items in the string[] are unique
 */
Array.prototype.unique = function(){
    return this.filter(function(s, i, a){ return i == a.lastIndexOf(s); });
}

