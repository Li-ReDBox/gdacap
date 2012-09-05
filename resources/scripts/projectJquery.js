/**
 * @author Andor Lundgren
 * @fileOverview In the ANDS project javascript related to the webpage is devided into two files:
 *  projectJavascript.js - all pure javascript functions and classes
 *  projectJquery.js     - all jQuery functions
 * projectJquery.js's functions mostly handles ajax calls to the server or sets up dialog windows to the user.
 * Mostly the format of the data sent to server is in JSON and uses posts (because the JSON is large).
 */

/** Show processes which take a file in a pop-up window*/ 
function process_popup(url) {
var windowOptions = "width=600,height=400,top=100,left=100";
var myWin = window.open( url, "File information", windowOptions );
}

/** showCommandParameters opens a dialog that shows the parameter options for a command */
function showCommandParameters(html){
    var $dialog = $('<div class="ui-widget"></div>')
		.html(html)
		.dialog({
			autoOpen: false,
			title: 'Edit Command parameters',
			height: 'auto',
			width: 'auto',
			show: {
                effect: "fade",
                duration: 1000
            },
            hide: {
                effect: "fade",
                duration: 500
            }
		});
    $dialog.dialog('open');
}

/** showHelpDialog opens a dialog that shows the help information*/
function showHelpDialog(html){
    var $dialog = $('<div class="ui-widget"></div>')
		.html(html)
		.dialog({
			autoOpen: false,
			title: 'Help',
			height: 'auto',
			width: 'auto',
			position: 'left'
    	});
    $dialog.dialog('open');
}

/** showDialog opens a dialog that shows the html to the user */
function showDialog(html, title){
    var $dialog = $('<div class="ui-widget"></div>')
		.html(html)
		.dialog({
			autoOpen: false,
			title: title,
			height: 'auto',
			width: 'auto',
			position: 'center'
		});
    $dialog.dialog('open');
}

/** getHelpJson is not in use but was created to be able to open a help dialog window with help information from server on the same page instead as know to 
 * be opened on a seperate page. The function getHelpJson will fetch help from server from a subject in the url and will show the html
 * help information without login_bar and wrapper in a dialog.
 */    
function getHelpJson(url) {
    $.ajax({
            url:       url,
            dataType: "json",
            type:     "post",            
            success:    function( data ){
                            if( $.isEmptyObject( data ) ){
                                alert('some error occurred..');
                            }
                            else{
                                /*{
                                    "help": "SOMETHING"
                                }*/
                                if( ! $.isEmptyObject( data.help ) ){
                                    showHelpDialog( data.help );
                                }
                            }
                        },
            error:      function(jqXHR, textStatus, errorThrown)
                        {
                            //Handle any errors
                            alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                        }
    });
};

/** getGraphvizSvgFromProcessId gets a svg from server and inserts it in the divPreviewGraph.
 * The input is a select where the selected value has the process_id of the process that is going to be fetched 
 */
function getGraphvizSvgFromProcessId(select) {
    var id = document.getElementById(select);
    var url  = $("#get_graphviz_with_process_id_url").val();
    var processId = $(id).val();
    var previewgraph = new Previewgraph();
    var previewGraphUrl = url + '?json=' + encodeURIComponent(JSON.stringify(previewgraph.toJson())) + '&process_id=' + processId;
    document.getElementById('aGraphSvg').setAttribute('href', previewGraphUrl ); // update url for the svg for the user to download in a new window
    $("#aGraphSvg").show();
    $("#btnEditGraphvizObject").hide();

    if(processId){
        $.ajax({
                    url:       url,
                    dataType: "text",
                    type:     "post",                    
                    data:       {
                                    process_id: processId,
                                    json: JSON.stringify( previewgraph.toJson() ), // use default setup in graph object for preview
                                },

                    success:    function( data ){
                                    if( $.isEmptyObject( data ) ){
                                        alert('some error occurred..');
                                    }
                                    else{
                                        var svg = new String(data);
                                        document.getElementById('divPreviewGraph').innerHTML = svg;
                                        updateGraphLabelName(svg);
                                    }
                                },
                    error:      function(jqXHR, textStatus, errorThrown)
                                {
                                    //Handle any errors
                                    alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                }
        });
    }
};

/** updateGraphLabelName updates the label for the previewGraph. 
 * It is called after the previewGraph have been updated from function getGraphvizSvgFromProcessId which loads a preview graph from a process that has been stored. 
 * It will change the label in the manner that the Job button will be clickable.
 * Once clicked refreshes the svg graph with the svg from the drag and drop table and after that removes the clickability from the label.
 */
function updateGraphLabelName(svg){
    var divPreviewLabel = document.getElementById('divPreviewGraphLabel');
    var divHTML;
    if(svg){
        divHTML = 'Preview/<a onclick="clientCommandConstructor.updatePreviewGraph();document.getElementById(\'divPreviewGraphLabel\').innerHTML=\'Preview/Job\'" style="color: blue; cursor: pointer; text-decoration: underline">Job</a>';}
    else{
       divHTML = 'Preview/Job';
    }
    divPreviewLabel.innerHTML = divHTML;
}

/** getGraphvizSvg gets the svg from input JSON formated graphviz object, inserts the svg into the preview and calls functions that:
 * 1. adds transparent black to all nodes
 * 2. add mouse events to the svg
 * 3. add mouse events to the drag and drop table
 * 4. updates the graph label name (removes the clickability)
 */
function getGraphvizSvg(commandConstructor, json) {
    var url  = $("#get_graphviz_url").val();
    var data = json;
    
    document.getElementById('aGraphSvg').setAttribute('href', url + '?json=' + encodeURIComponent(data) ); // update url for the svg for the user to download in a new window
    $("#aGraphSvg").show(); 
    $("#btnEditGraphvizObject").show();
    
    if(data != ''){
        $.ajax({
                    url:       url,
                    dataType: "text",
                    type:     "post",                    
                    data:       {
                                    json: data,
                                },

                    success:    function( data ){
                                    if( $.isEmptyObject( data ) ){
                                        alert('some error occurred..');
                                    }
                                    else{
                                        document.getElementById('divPreviewGraph').innerHTML = new String(data);
                                        // add onmouseover on the nodes
                                        commandConstructor.previewgraph.addTransparentBlackBackgroundToAllNodes();
                                        commandConstructor.previewgraph.addMouseEventsToSvg(commandConstructor);
                                        addMouseEventsToTableRow(commandConstructor);
                                        updateGraphLabelName();
                                    }
                                },
                    error:      function(jqXHR, textStatus, errorThrown)
                                {
                                    //Handle any errors
                                    alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                }
        });
    }
};

/** addMouseEventsToTableRow adds onmouseover and onmouseout highlighting on the row of the drag and drop table */
function addMouseEventsToTableRow(commandConstructor){
    var tbl = document.getElementById('tblProcesses');
    if(tbl){
        for (var i = 0, row; row = tbl.rows[i]; i++) {              // create array of unique id's for each row (all the steps)
             var id = getRowId(row);
             if( id != 0 ){
                var processId;
                var inputs = row.getElementsByTagName('input');
                for(var j = 0; j < inputs.length; j++) {
                    // get processId
                    if( inputs[j].id.indexOf("hiProcessId") != -1){
                        processId = inputs[j].value;
                        row.setAttribute('onmouseover', commandConstructor.name + '.previewgraph.highlightSvgObjectWithId(\'' + processId + '\')');
                        row.setAttribute('onmouseout',  commandConstructor.name + '.previewgraph.unhighlightSvgObjectWithId(\'' + processId + '\')');
                        break
                    }
                }

             }
        }
    }
}

/** getCommandLinesPreview gets the commandlines for the processes in the commmandConstructor and either:
 * calls the commandConstructors update previewGraph function (if a update previewgraph was called and the show commands instead of nodes is set to true)
 * shows the commandlines in a dialog to the user (if user clicked preview button) 
 */
function getCommandLinesPreview(commandConstructor, updatePreviewGraphAfterResponse) {
    var url = $("#get_bash_command_url").val();
    var data;
    if(updatePreviewGraphAfterResponse == true){// on show commands in graph, we can not demand that the commands should be correct, no graph will be displayed (which gives hints on what is missing)
        var allowNotCompleteRows = true;
        data = createExecutionTable(commandConstructor, allowNotCompleteRows);
    }
    else{// on preview of commands we demand that all inputs are ok before preview
        data = createRun(commandConstructor);
    }

    if(data != ''){
        $.ajax({
                    url:       url,
                    dataType: "json",
                    type:     "post",
                    data:       {
                                    shortFileNames: updatePreviewGraphAfterResponse,
                                    json: data,
                                },
                    success:    function( data ){
                                    if( $.isEmptyObject( data ) ){
                                        alert('some error occurred..');
                                    }
                                    else{
                                        /*{
                                            "steps": [
                                                {
                                                    "step": 0,
                                                    "process_id": "PROCESS.ID"
                                                    "command": "SOMETHING"
                                                },
                                                {
                                                    "step": 1,
                                                    "process_id": "PROCESS.ID"
                                                    "command": "SOMETHING"
                                                }
                                            ]
                                        }*/
                                        var commandlines = new Commandlines();
                                        if( ! $.isEmptyObject( data.steps ) ){
                                            $.each(data.steps, function(){
                                                var commandline = new Commandline();
                                                commandline.set(this.step, this.process_id, this.command);
                                                commandlines.add(commandline);
                                            });
                                        }
                                        if(updatePreviewGraphAfterResponse){// person want graph with commandtext in the graph
                                            commandConstructor.updatePreviewGraphWithCommandlines(commandlines);
                                        }
                                        else{// person clicked preview command
                                            var title = commandlines.commandline.length > 1 ? 'Commands preview' : 'Command preview';
                                            showDialog(commandlines.getCommands(), title);
                                        }
                                    }
                                },
                    error:      function(jqXHR, textStatus, errorThrown)
                                {
                                    //Handle any errors
                                    alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                }
        });
    }
};


$(document).ready(function() {
    /** JQuery function call that adds sorting to all tables with the class "tblSortable tablesorter".
     * @function
     * @name jQuery_tablesorter
     */
    $(".tblSortable").tablesorter();
    
    /** JQuery function call that adds a jQuery DatePicker on all inputs with type="date"
     * If a browser does support a input with type="date" it will do nothing but if it does
     * not it will add the jQuery datepicker.
     * @function
     * @name jQuery_replaceDateInputs
     */
    $('input[type="date"]').each(function() {
        if (!checkInput("date")) {
            $(this).datepicker({ dateFormat: "yy-mm-dd" });            
        }
    });
    
    /** checkInput checks if a browser supports a type for a input
     * @function
     * @name checkInput
     * @param {string} type type of input to test
     * @returns true|false
     */
    function checkInput(type) {
        var input = document.createElement("input");
        input.setAttribute("type", type);
        return input.type == type;
    }    
    
    /** JQuery function call that hides all old buttons and replaces it with a button with a icon on.
     * The buttons that are replaced are those with matching names for 'or search' and 'hide search'.
     * @function
     * @name jQuery_replaceButtons
     */
    $('button').each(function() {
        var value = $(this).html();
        switch(value){
            case 'or search':
                $(this).hide().after('<button>').next().button({    // hide the submit, insert a button with theses values
	                icons: {
		                primary: 'ui-icon-search',
	                },
	                text: false,
                }).click(function(event) {                          // add onclick to the button
	                event.preventDefault();
	                $(this).prev().click();
                }).addClass("btnSubmitImage");
            break;
            case 'hide search':
                $(this).hide().after('<button>').next().button({    // hide the submit, insert a button with theses values
	                icons: {
		                primary: 'ui-icon-cancel',
	                },
	                text: false,
                }).click(function(event) {                          // add onclick to the button
	                event.preventDefault();
	                $(this).prev().click();
                }).addClass("btnSubmitImage");
            break;
	        default:
        }
    });
    
    /** JQuery function call that hides submit input buttons and replaces it with a button with a icon on it.
     * All values (names and values) in a input are not posted in the same way (in all browsers) if they are replaced with a button
     * therefore hiding the button and showing a icon button that submits the hidden button is the best way to go.
     * @function
     * @name jQuery_replaceSubmitInputs
     */
    $('input[type="submit"]').each(function() {
        var value = $(this).prop("value");
        switch(value){
            case 'Add':
	            $(this).hide().after('<button>').next().button({    // hide the submit, insert a button with theses values
		            icons: {
			            primary: 'ui-icon-plus',
		            },
		            text: false,
	            }).click(function(event) {                          // add onclick to the button
		            event.preventDefault();
		            $(this).prev().click();
	            }).addClass("btnSubmitImage");
	            break;
	        case 'Edit':
	            $(this).hide().after('<button>').next().button({    // hide the submit, insert a button with theses values
		            icons: {
			            primary: 'ui-icon-pencil',
		            },
		            text: false,
	            }).click(function(event) {                          // add onclick to the button
		            event.preventDefault();
		            $(this).prev().click();
	            }).addClass("btnSubmitImage");
	            break;
            case 'Open':
	            $(this).hide().after('<button>').next().button({    // hide the submit, insert a button with theses values
		            icons: {
			            primary: 'ui-icon-folder-open',
		            },
		            text: false,
	            }).click(function(event) {                          // add onclick to the button
		            event.preventDefault();
		            $(this).prev().click();
	            }).addClass("btnSubmitImage");
	            break;
            case 'Save':
	            $(this).hide().after('<button>').next().button({    // hide the submit, insert a button with theses values
		            icons: {
			            primary: 'ui-icon-disk',
		            },
		            text: false,
		            //label: $(this).val()// if you want text instead of just a icon button, remove text:false and uncomment label
	            }).click(function(event) {                          // add onclick to the button
		            event.preventDefault();
		            $(this).prev().click();
	            }).addClass("btnSubmitImage");
	            break;
            default:
                // otherObjects
        }
    });
        
    /** JQuery function that handles click event on objects with class "ulShowProjectNavigationLinks".
     * Some pages wich relates to project have a project navigation at the bottom of the page, this code below is about hiding and showing that field
     * @function
     * @name jQuery_click_ulShowProjectNavigationLinks
     */
    $('#ulShowProjectNavigationLinks').click(function() {
        $('#ulShowProjectNavigationLinks').slideUp("fast", function(){
            $('#ulProjectNavigationLinks').slideDown("slow", function(){
                $('#ulHideProjectNavigationLinks').slideDown("slow", function(){
                });
            });
        });
    });

    /** JQuery function that handles click event on objects with class "ulHideProjectNavigationLinks".
     * Some pages wich relates to project have a project navigation at the bottom of the page, this code below is about hiding and showing that field
     * @function
     * @name jQuery_click_ulHideProjectNavigationLinks
     */
    $('#ulHideProjectNavigationLinks').click(function() {
        $('#ulHideProjectNavigationLinks').slideUp('fast', function(){
            $('#ulProjectNavigationLinks').slideUp('slow', function() {
                $('#ulShowProjectNavigationLinks').show("fast");
            });
            
        });
        
    });

    /** Anonymous function that is mapped to id of anzsrc, which handles autocomplete for the anzsrc
     * @function
     * @name jQuery_autocomplete_anzsrc
     */
    $(function() {
		$( "#anzsrc" ).autocomplete({
			source: function( request, response ) 
			{
                    var url = $("#anzsrc_url" ).val();
			    
                    $.ajax({
                        url:       url,
                        dataType: "json",
                        type:     "post",                        
                        data:       {
                                        //url: function () { return  $("#anzsrc_url" ).val(); }, // why  can't I do this?? (above for url)... probably because it is async or?
                                        max_rows: 10,
                                        search_all: request.term,
                                    },

                        success:    function( data ){
                                        if( $.isEmptyObject( data ) ){
                                            // do nothing if nothing is returned
                                        }
                                        else{
                                            response( $.map( data.anzsrcs, function( item ){
                                                return { label: item.for_name  + "  (" + item.for_code + ")" , value: item.for_name + " (" + item.for_code + ")", id: item.for_code }
                                                }));
                                        }
                                    },
                        error:      function(jqXHR, textStatus, errorThrown){
                                        //Handle any errors
                                        alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                    }
                    });
			},
			minLength: 2,
			select: function( event, ui ) {
				
				// when item selected
				$( "#anzsrc_for_code" ).val( ui.item.id );  // set 
				$( ".liSearchAnzsrc"  ).hide();  
                $( ".liChoosenAnzsrc" ).show();  
			},
			open: function() {
				$( this ).removeClass( "ui-corner-all" ).addClass( "ui-corner-top" );
			},
			close: function() {
				$( this ).removeClass( "ui-corner-top" ).addClass( "ui-corner-all" );
			}
		});
	});
	
    //--Show/hide button_Start 
    /** Anonymous function that is mapped to id of btnShowSearchAnzsrc, which handles show and hiding of the Search ANZSRC field.
     * For the function to work there also exist anonymous functions for 
     * $("#anzsrc").focusout()
     * $(".ui-menu-item").keypress()
     * $("#btnShowChoosenAnzsrc").click()
     * they are not documented by them self but mentioned here:
     * These functions show/hides the search field of anzsrc. The search field is hidden from start and when a search is made
     * and either item in autocomplete list is selected or user make the search field out of focus the search field is hidden and the dropdown is shown.
     * The anonymous function jQuery_autocomplete_anzsrc is the one that selectes the choosen value in the autocomplete field to the dropdown.
     * @function
     * @name jQuery_click_btnShowSearchAnzsrc
     */
    $( "#btnShowSearchAnzsrc" ).click(function(){
                                                        $( ".liSearchAnzsrc"  ).toggle();   // through css always hidden  from start
                                                        $( "#anzsrc"  ).val('');
                                                        $( "#anzsrc"  ).focus();            
                                                        $( ".liChoosenAnzsrc" ).toggle();   // through css always visible from start
                                                });
    $( "#anzsrc" ).focusout(function(){
                                                        $( ".liSearchAnzsrc"  ).hide();  
                                                        $( ".liChoosenAnzsrc" ).show();  
                                                });
    $(".ui-menu-item").keypress(function(e){
                                                    if(e.keyCode == 13) {
                                                        $( ".liSearchAnzsrc"  ).hide();  
                                                        $( ".liChoosenAnzsrc" ).show();  
                                                        }
                                                });
    $( "#btnShowChoosenAnzsrc" ).click(function(){
                                                        $( ".liSearchAnzsrc"  ).hide();  
                                                        $( ".liChoosenAnzsrc" ).show();  
                                                });
    //--Show/hide button_End
    

    /** Anonymous function that is mapped to id of tax_id_search, which handles autocomplete for the tax_ids
     * @function
     * @name jQuery_autocomplete_tax_id_search
     */
    $(function() {

		$( "#tax_id_search" ).autocomplete({
			source: function( request, response ) 
			{
			    
                    var url = $("#tax_id_url" ).val();
			    
                    $.ajax({
                        url:       url,
                        dataType: "json",
                        type:     "post",                        
                        data:       {
                                        max_rows: 50,
                                        search_all: request.term,
                                    },

                        success:    function( data ){
                                        response( $.map( data.taxnames, function( item ){
                                            return { label: item.tax_id  + " (" + item.name_txt + " - " + item.name_class + ")" , value: item.name_txt  + " (" + item.tax_id + ")", id: item.tax_id }
                                            }));
                                    },
                        error:      function(jqXHR, textStatus, errorThrown)
                                    {
                                        //Handle any errors
                                        alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                    }
                    });
			},
			minLength: 3,
			select: function( event, ui ) {
				// when item selected
				$( '#tax_id' ).val( ui.item.id );  // set choosen tax_id
				$( '#liTax' ).hide();              // hide if there were any privous showing info about old tax_id
				$( '#btnGetTax' ).show();           
                $( '#btnHideTaxInfo' ).hide();
			},
			open: function() {
				$( this ).removeClass( "ui-corner-all" ).addClass( "ui-corner-top" );
			},
			close: function() {
				$( this ).removeClass( "ui-corner-top" ).addClass( "ui-corner-all" );
			}
		}).keydown(function(e){
            // when user is under firefox and press enter key on input it will submit and not select the value
            // that is in the autocomplete form (which will insert the correct tax_id into the hidden input)
            // to control that the user is always forced to select the right value the key enter is disabled on that input
            if (e.which === 13){// in jQuery e.which is a normalized value for all browsers to work on
                return false;
            }
           });
	});

    /** Anonymous function that handles retrieval of tax_id information 
     * @function
     * @name jQuery_click_btnGetTax
     */
    $('#btnGetTax').click(function() {
        var url = $("#tax_info_url").val();
        $.ajax({
                    url:       url,
                    dataType: "json",
                    type:     "post",                    
                    data:       {
                                    tax_id: $("#tax_id").val(),
                                },

                    success:    function( data ){
                                    // create table of json response
                                    var tax_table = '<table>\
                                                        <thead>\
                                                            <tr>\
                                                                <th>Tax id</th>\
                                                                <th>Name</th>\
                                                                <th>Name Class</th>\
                                                            </tr>\
                                                        </thead>\
                                                        <tbody>';
                                    $.each(data.taxnames, function(){
                                        tax_table += '<tr>';
                                        var tax_id, name_txt, name_class;
                                        $.each(this, function(key, value){
                                            switch(key)
                                            {
                                                case 'tax_id': 
                                                    tax_id = value;
                                                    break;
                                                case 'name_txt': 
                                                    name_txt = value
                                                    break;
                                                case 'name_class':
                                                    name_class = value;
                                                  break;
                                                default:
                                            }    
                                        });
                                        tax_table += '<td>' + tax_id + '</td><td>' + name_txt + '</td><td>' + name_class + '</td>';
                                        tax_table += '</tr>';
                                    });
                                    tax_table +=        '</tbody>\
                                                     </table>';
                                    // add table to li
                                    document.getElementById('liTax').innerHTML = tax_table;
                                    
                                    $( '#liTax' ).show();                              
                                    $( '#btnGetTax' ).hide();        // hide show more info
                                    $( '#btnHideTaxInfo' ).show();   // show hide button
                                    
                                },
                    error:      function(jqXHR, textStatus, errorThrown)
                                {
                                    //Handle any errors
                                    alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                }
                });
    });
    $('#btnHideTaxInfo').click( function(){
        $( '#btnGetTax' ).show();
        $( '#btnHideTaxInfo' ).hide();
        $( '#liTax' ).hide();
        });
    
    /** Function that handles retrieval of processDependencies, removed */    
    /*$('#btnGetProcessDependencies').click(function() {
        if( $("#process_id").val() > 0 ){
            
            var url = $("#process_dependency_info_url").val();
            $.ajax({
                        url:       url,
                        dataType: "json",
                        type:     "post",                        
                        data:       {
                                        process_id: $("#process_id").val(),
                                    },

                        success:    function( data ){
                                        if( $.isEmptyObject( data ) ){
                                            document.getElementById('liProcesses').innerHTML = "No dependencies";
                                            
                                            $( '#liProcesses' ).show();                              
                                            $( '#btnGetProcessDependencies' ).hide();        // hide show more info
                                            $( '#btnHideProcessDependencies' ).show();   // show hide button
                                        }
                                        else{
                                            // create table of json response
                                            var dep_table = '<table>\
                                                                <thead>\
                                                                    <tr>\
                                                                        <th>process_id</th>\
                                                                        <th>parent_process_id</th>\
                                                                        <th>iname</th>\
                                                                        <th>description</th>\
                                                                        <th>command_text</th>\
                                                                        <th>software_iname</th>\
                                                                    </tr>\
                                                                </thead>\
                                                                <tbody>';
                                                                
                                            // sort the data on level
                                            data.process_dependencies.sort(function (a, b) {
                                                a = a.level,
                                                b = b.level;
                                                return a < b ? 1 : -1;
                                                //return a.localeCompare(b);
                                            });                      
                                                                
                                            $.each(data.process_dependencies, function(){
                                                dep_table += '<tr>';
                                                var process_id, parent_process_id, iname, description, command_text, software_id, level;
                                                
                                                process_id          = this.process_id;
                                                parent_process_id   = this.parent_process_id;
                                                level               = this.level;
                                                
                                                // get parent process information (the process_id's parent process information)
                                                $.each(data.parent_processes.processes, function(){
                                                    if(this.id == parent_process_id){
                                                        $.each(this, function(key, value){
                                                            switch(key){
                                                                case 'iname': 
                                                                    iname = value;
                                                                    break;
                                                                case 'description': 
                                                                    description = value;
                                                                    break;
                                                                case 'command_text': 
                                                                    command_text = value;
                                                                    break;
                                                                case 'software_id': 
                                                                    software_id = value;
                                                                    break;
                                                                default:
                                                            }
                                                        });
                                                    }
                                                });
                                                
                                                var software_iname;
                                                // get parent software information
                                                $.each(data.parent_processes.softwares.softwares, function(){
                                                    if(this.id == software_id){
                                                        $.each(this, function(key, value){
                                                            switch(key){
                                                                case 'iname': 
                                                                    software_iname = value;
                                                                    break;
                                                                default:
                                                            }
                                                        });
                                                    }
                                                });
                                    
                                                dep_table += '<td>' + process_id + '</td><td>' + parent_process_id + '</td><td>' + iname + '</td><td>' + description + '</td><td>' + command_text + '</td><td>' + software_iname + '</td><td>' + level + '</td>';
                                                dep_table += '</tr>';
                                            });
                                            dep_table +=        '</tbody>\
                                                             </table>';
                                            // add table to li
                                            document.getElementById('liProcesses').innerHTML = dep_table;
                                            
                                            $( '#liProcesses' ).show();                              
                                            $( '#btnGetProcessDependencies' ).hide();        // hide show more info
                                            $( '#btnHideProcessDependencies' ).show();   // show hide button
                                        }
                                    },
                        error:      function(jqXHR, textStatus, errorThrown)
                                    {
                                        //Handle any errors
                                        alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                    }
                    });
            }
    });
    $('#btnHideProcessDependencies').click( function(){
        $( '#btnGetProcessDependencies' ).show();
        $( '#btnHideProcessDependencies' ).hide();
        $( '#liProcesses' ).hide();
        });
     $('#process_id').change( function(){
        $( '#btnGetProcessDependencies' ).show();
        $( '#btnHideProcessDependencies' ).hide();
        $( '#liProcesses' ).hide();
        });
        */

    /** Anonymous function that handles adding of a command to drag and drop table
     * @function
     * @name jQuery_click_btnAddCommand
     */
    $('#btnAddCommand').click(function() {
         getCommand(clientCommandConstructor); // global object that we should add the response to
    });
    
    /** Function that adds the command to the commandconstructor
     * @function
     * @name gotAnswerFromGetCommand
     * @param {CommandConstructor} commandConstructor commandConstructor contains all information needed to describe the command retrieved
     * @param {CommandConstructor} globalCommandConstructor globalCommandConstructor is the global object that the retrieved commandConstructor is going to be added to 
     */
    function gotAnswerFromGetCommand(commandConstructor, globalCommandConstructor){
        // create process for the command before adding it
        commandConstructor.createDummyValues();

        // copy contents from recieved to global value
        globalCommandConstructor.add(commandConstructor);

        // add commandConstructor processes to the drag and drop table
        var   hasCalledDragAndDropTable = addCommandConstructorProcessesToTable(commandConstructor, globalCommandConstructor, false);
        
        if ( !hasCalledDragAndDropTable ){
            updateAllDroppableClasses();  // update apperance on all droppable zones
            globalCommandConstructor.updatePreviewGraph();// update preview of graph
        }
    }
    
    /** Function that gets command information from server
     * @function
     * @name getCommand
     * @param {CommandConstructor} globalCommandConstructor globalCommandConstructor is the global object that the retrieved commandConstructor is going to be added to 
     */
    function getCommand(globalCommandConstructor) {
        
        if( $("#command_id").val() > 0 ){
            
            var url = $("#get_command_url").val();
            $.ajax({
                        url:       url,
                        dataType: "json",
                        type:     "post",                        
                        data:       {
                                        command_id: $("#command_id").val(),
                                    },

                        success:    function( data ){
                                        if( $.isEmptyObject( data ) ){
                                            alert('Could not find that command..');
                                        }
                                        else{
                                            var commandConstructor = new CommandConstructor('tmp'); // where to store the response temporary
                                            
                                            // json data recieved comes in several groups of objects
                                            // 1. command
                                            // 2. filetypes      (all filetypes associated with the command)
                                            // 3. parameters     (all parameters the command has)
                                            // 4. parametertypes (the parametertypes the parameters have)
                                            // 5. software       (the software the command is associated with)
                                    
                                            /*  "command" :
                                                {
                                                    "software_id" : 1,
                                                    "iname" : "Samtools sorte",
                                                    "id" : 1,
                                                    "description" : "Samtools sort."
                                                }
                                            */
                                            if( ! $.isEmptyObject( data.command ) ){
                                                var command = new Command();
                                                command.set(data.command.id,data.command.iname,data.command.description,data.command.software_id);
                                                commandConstructor.addCommand(command);
                                            }
                                            
                                            /*"filetypes" : [
                                            {
                                                    "extension" : "bam",
                                                    "iname" : "BAM",
                                                    "id" : 3,
                                                    "parent_file_type_id" : 1
                                            },*/
                                            if( ! $.isEmptyObject( data.filetypes ) ){
                                                    $.each(data.filetypes.filetypes, function(){
                                                        if( !commandConstructor.filetypes.exists(this.id) ){
                                                            var filetype = new Filetype();
                                                            filetype.set(this.id, this.iname, this.extension, this.parent_file_type_id);
                                                            commandConstructor.addFiletype(filetype);
                                                        }
                                                    });
                                            }
                                        
                                            /*"parameters" : [
                                            {
                                                "max_items" : 0,
                                                "is_mandatory" : "1",
                                                "template" : "samtools",
                                                "min_items" : 0,
                                                "command_id" : 1,
                                                "locus" : 0,
                                                "description" : "Main command",
                                                "iname" : "command",
                                                "parameter_type_id" : 1,
                                                "id" : 1
                                             },*/
                                            if( ! $.isEmptyObject( data.parameters ) ){
                                                $.each(data.parameters.parameters, function(){
                                                    var parameter = new Parameter();
                                                    parameter.set(this.id, this.iname, this.description, this.template, this.is_mandatory, this.locus, this.min_items, this.max_items, this.parameter_type_id, this.command_id);
                                                    commandConstructor.addParameter(parameter);
                                                });
                                            }
                                            
                                            /*"parametertypes" : [
                                             {
                                                "iname" : "string",
                                                "file_type_id" : null,
                                                "id" : 1,
                                                "description" : "a string"
                                             },*/
                                             if( ! $.isEmptyObject( data.parametertypes ) ){
                                                $.each(data.parametertypes.parametertypes, function(){
                                                    var parametertype = new Parametertype();
                                                    parametertype.set(this.id, this.iname, this.description, this.file_type_id);
                                                    commandConstructor.addParametertype(parametertype);
                                                });
                                            }
                                            
                                            /*""software" : 
                                             {
                                                "version" : "some version",
                                                "iname" : "Samtools",
                                                "id" : 1,
                                                "description" : "Various utilities for processing alignments in the SAM format, including variant calling and alignment viewing."
                                             }
                                            */
                                            if( ! $.isEmptyObject( data.software ) ){
                                                var software = new Software();
                                                software.set(data.software.id,data.software.iname,data.software.description,data.software.version);
                                                commandConstructor.addSoftware(software);
                                            }
                                            
                                            gotAnswerFromGetCommand(commandConstructor, globalCommandConstructor);
                                        }
                                    },
                        error:      function(jqXHR, textStatus, errorThrown){
                                        //Handle any errors
                                        alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                    }
                    });
            }
    };

    /** addCommandConstructorProcessesToTable adds the processes from a commandConstructor to a table.
     * If no table exist it creates a new table and inserts it on the drag and drop place.
     * @function
     * @name addCommandConstructorProcessesToTable
     * @param {CommandConstructor} commandConstructor commandConstructor contains all information needed to describe the command retrieved
     * @param {CommandConstructor} globalCommandConstructor globalCommandConstructor is the global object that has the drag and drop table that the commandConstructor's processes is going to be added to
     * @param {boolean} addDraggedFiles addDraggedFiles describes if the files that exist in the commandConstructor is going to be added as well as the processes to the globalCommandConstructor
     */
    function addCommandConstructorProcessesToTable(commandConstructor, globalCommandConstructor, addDraggedFiles){
        var hasCalledDragAndDropTable = false;
        
        // check table if it already exist, if so add each process in commandConstructor and call 
        var table = document.getElementById('tblProcesses');
        if(addDraggedFiles){
            refreshDragAndDropTable(globalCommandConstructor);
            hasCalledDragAndDropTable = true;
        }
        else if( !table ) {
            createTable(globalCommandConstructor, 'liBuildRun', false);
            globalCommandConstructor.updateProcessParameterValuesFromTable('tblProcesses'); // update the values so that if show preview of commands is used the processoutputs will have a value
                                                                                            // without it the filename for the output would be NONAME which is not prefered
        }
        else{
            var tbl     = document.getElementById('tblProcesses');
            var tbody   = tbl.getElementsByTagName('tbody');   // returns array of objects, but it should only contain one
            var rows = '';
            for(var i = 0; i < commandConstructor.processes.process.length; i++){
                // if a process with the same id already exist in the table, do not add the process to the table (will create a duplicate)
                // when adding from command it will never be a collision but if you try to add old stored processes twice it will
                if( ! isProcessInTable(globalCommandConstructor, commandConstructor.processes.process[i].id, 'tblProcesses') ){
                    rows += createTableRow(globalCommandConstructor, commandConstructor.processes.process[i].id, addDraggedFiles);
                }
            }
            
            // after adding rows to the table the processparametervalues in the outputs does not exist in the commandconstructor
            // this will cause the function with showexecutioncommand preview to send empty values for the outputfiles which will get the name NONAME
            // if we update the values from the table this will be fixed, so therefore we do this update here aswell as in the if no table exist above
            globalCommandConstructor.updateProcessParameterValuesFromTable('tblProcesses');
            
            tbody[0].innerHTML += rows;                         // add to first tbody element (should only be one)
        }
        $( '#liBuildRun' ).show();                              // ensure that the div containing the table are visible
        
        return hasCalledDragAndDropTable;
    }
    
    /** Anonymous function that adds a previously stored process to the drag and drop table, but without the dependencies (files)
     * @function
     * @name jQuery_click_btnAddProcess
     */
    $('#btnAddProcess').click(function() {
        getProcesses(clientCommandConstructor, false); // global object that we should add the response to
        // update apperance on all droppable zones
        updateAllDroppableClasses();
        clientCommandConstructor.updatePreviewGraph();// update preview of graph
    });
    
    /** Anonymous function that adds a previously stored process to the drag and drop table, with the dependencies(files)
     * @function
     * @name jQuery_click_btnAddProcessWithDependencies
     */
    $('#btnAddProcessWithDependencies').click(function() {
        getProcesses(clientCommandConstructor, true); // global object that we should add the response to
        // update apperance on all droppable zones
        updateAllDroppableClasses();
        clientCommandConstructor.updatePreviewGraph();// update preview of graph
    });
    
    /** gotAnswerFromGetProcesses adds the information got from server about a process and its files to a commandConstructor 
     * and then updates the drag and drop table and its droppables if necessary 
     * @function
     * @name gotAnswerFromGetProcesses
     * @param {CommandConstructor} commandConstructor commandConstructor contains all information needed to describe the command retrieved (with processes)
     * @param {CommandConstructor} globalCommandConstructor globalCommandConstructor is the global object that has the drag and drop table that the commandConstructor's processes is going to be added to
     * @param {boolean} addDraggedFiles addDraggedFiles describes if the files that exist in the commandConstructor is going to be added as well as the processes to the globalCommandConstructor
     */
    function gotAnswerFromGetProcesses(commandConstructor, globalCommandConstructor, addDraggedFiles){
        // remove the dependencies before the add because the dependencies are added manually if files are added
        commandConstructor.dependencies = new Dependencies();
        
        // copy contents from recieved to global value
        globalCommandConstructor.add(commandConstructor);
        
        // add new processes to the drag and drop table
        var hasCalledDragAndDropTable = addCommandConstructorProcessesToTable(commandConstructor, globalCommandConstructor, addDraggedFiles);
        if ( !hasCalledDragAndDropTable ){
            updateAllDroppableClasses();  // update apperance on all droppable zones
            globalCommandConstructor.updatePreviewGraph();// update preview of graph
        }
    }

    /** getProcesses gets information about a specific process and its dependencies and passes the information to the function gotAnswerFromGetProcesses 
     * @function
     * @name getProcesses
     * @param {CommandConstructor} globalCommandConstructor globalCommandConstructor is the global object that has the drag and drop table that the commandConstructor's processes is going to be added to
     * @param {boolean} addDraggedFiles addDraggedFiles describes if the files that will be retrieved from the processes also is going to be added to the globalCommandConstructor
     */
    function getProcesses(globalCommandConstructor, addDraggedFiles) {
        if( $("#process_id").val() > 0 ){
            
            var url = $("#get_process_with_dependencies_url").val();
            $.ajax({
                        url:       url,
                        dataType: "json",
                        type:     "post",                        
                        data:       {
                                        process_id: $("#process_id").val(),
                                    },

                        success:    function( data ){
                                        if( $.isEmptyObject( data ) ){
                                            alert('some error occurred..');
                                        }
                                        else{
                                            var commandConstructor = new CommandConstructor('tmp'); // where to store the response temporary
                                            // json data recieved comes in several groups of objects
                                            // 1. process                (chosen process)
                                            // 2. dependencies           (chosen process dependencies)
                                            // 3. processes              (all processes, including chosen process)
                                            // 4. commands               (all commands)
                                            // 5. parameters             (all parameters)
                                            // 6. parametertypes         (all parameterertypes the parameters has)
                                            // 7. processparametervalues (the value a specifik process and parameter has)
                                            // 8. softwares              (all softwares)
                                            // 9. filetypes              (all filetypes)
                                            
                                            // fill all javascript objects with the data from the json message
                                            /*"process" : {
                                                  "iname" : "Alignment 1",
                                                  "id" : 1,
                                                  "description" : "Alignment",
                                                  "command_id" : 1,
                                                  "person_id" : 1,
                                                  "project_id" : 1,
                                                  "type" : 1
                                                }
                                            */
                                            
                                            var process = new Process();
                                            process.set(data.process.id,data.process.iname,data.process.description,data.process.command_id, data.process.project_id, data.process.person_id, data.process.type);
                                            commandConstructor.addProcess(process);
                                            
                                            /*process_dependencies" : [
                                                 {
                                                    "parent_process_id" : 5,
                                                    "level" : 0,
                                                    "process_id" : 6
                                                 },
                                                 {
                                                    "parent_process_id" : 4,
                                                    "level" : 1,
                                                    "process_id" : 5
                                                 }]
                                            */
                                            if( ! $.isEmptyObject( data.dependencies ) ){
                                                $.each(data.dependencies.process_dependencies, function(){
                                                    var dependency = new Dependency();
                                                    dependency.set(this.process_id, this.parent_process_id, this.level);
                                                    commandConstructor.addDependency(dependency);
                                                });
                                                
                                            }
                                            
                                            /*"processes" : [
                                                {
                                                    "command_id" : 1,
                                                    "iname" : "Variant Calling 1",
                                                    "id" : 2,
                                                    "description" : "Variant Calling decription"
                                                },
                                            */
                                            if( ! $.isEmptyObject( data.processes ) ){
                                                    $.each(data.processes.processes, function(){
                                                        if( !commandConstructor.processes.exists(this.id) ){// double check may not be needed
                                                            var process = new Process();
                                                            process.set(this.id, this.iname, this.description, this.command_id);
                                                            commandConstructor.addProcess(process);
                                                        }
                                                    });
                                            }
                                            
                                            /*"commands" : [
                                             {
                                                "software_id" : 1,
                                                "iname" : "Samtools sorte",
                                                "id" : 1,
                                                "description" : "Samtools sort."
                                             },
                                            */
                                            if( ! $.isEmptyObject( data.commands ) ){
                                                $.each(data.commands.commands, function(){
                                                    var command = new Command();
                                                    command.set(this.id,this.iname,this.description,this.software_id);
                                                    commandConstructor.addCommand(command);
                                                });
                                            }

                                            /*"parameters" : [
                                            {
                                                "max_items" : 0,
                                                "is_mandatory" : "1",
                                                "template" : "samtools",
                                                "min_items" : 0,
                                                "command_id" : 1,
                                                "locus" : 0,
                                                "description" : "Main command",
                                                "iname" : "command",
                                                "parameter_type_id" : 1,
                                                "id" : 1
                                             },*/
                                            if( ! $.isEmptyObject( data.parameters ) ){
                                                $.each(data.parameters.parameters, function(){
                                                    var parameter = new Parameter();
                                                    parameter.set(this.id, this.iname, this.description, this.template, this.is_mandatory, this.locus, this.min_items, this.max_items, this.parameter_type_id, this.command_id);
                                                    commandConstructor.addParameter(parameter);
                                                });
                                            }
                                            
                                            /*"parametertypes" : [
                                             {
                                                "iname" : "string",
                                                "file_type_id" : null,
                                                "id" : 1,
                                                "description" : "a string"
                                             },*/
                                             if( ! $.isEmptyObject( data.parametertypes ) ){
                                                $.each(data.parametertypes.parametertypes, function(){
                                                    var parametertype = new Parametertype();
                                                    parametertype.set(this.id, this.iname, this.description, this.file_type_id);
                                                    commandConstructor.addParametertype(parametertype);
                                                });
                                            }
                                            
                                            /*"processparametervalues" : [
                                             {
                                                "parameter_id" : 1,
                                                "process_id" : 1,
                                                "value" : "",
                                                "id" : 1,
                                                "locus" : 0
                                             },*/
                                            if( ! $.isEmptyObject( data.processparametervalues ) ){
                                                $.each(data.processparametervalues.processparametervalues, function(){
                                                    var processparametervalue = new Processparametervalue();
                                                    processparametervalue.set(this.id, this.process_id, this.parameter_id, this.value, this.locus);
                                                    commandConstructor.addProcessparametervalue(processparametervalue);
                                                });
                                            }

                                            /*""softwares" : [
                                             {
                                                "version" : "some version",
                                                "iname" : "Samtools",
                                                "id" : 1,
                                                "description" : "Various utilities for processing alignments in the SAM format, including variant calling and alignment viewing."
                                             }
                                            */
                                            if( ! $.isEmptyObject( data.softwares ) ){
                                                $.each(data.softwares.softwares, function(){
                                                    var software = new Software();
                                                    software.set(this.id,this.iname,this.description,this.version);
                                                    commandConstructor.addSoftware(software);
                                                });
                                            }
                                            
                                            /*"commands" : [
                                                {
                                                    "software_id" : 1,
                                                    "iname" : "zip",
                                                    "id" : 1,
                                                    "description" : "zip"
                                                 }
                                            */
                                            if( ! $.isEmptyObject( data.commands ) ){
                                                $.each(data.commands.commands, function(){
                                                    var command = new Command();
                                                    command.set(this.id,this.iname,this.description,this.software_id);
                                                    commandConstructor.addCommand(command);
                                                });
                                            }

                                            /*"filetypes" : {
                                                    "filetypes" : [
                                                        {
                                                            "extension" : "bam",
                                                            "iname" : "BAM",
                                                            "id" : 3,
                                                            "parent_file_type_id" : "1"
                                                        }
                                                    ]
                                                }
                                            */
                                            if( ! $.isEmptyObject( data.filetypes ) ){
                                                    $.each(data.filetypes.filetypes, function(){
                                                        if( !commandConstructor.filetypes.exists(this.id) ){
                                                            var filetype = new Filetype();
                                                            filetype.set(this.id, this.iname, this.extension, this.parent_file_type_id);
                                                            commandConstructor.addFiletype(filetype);
                                                        }
                                                    });
                                            }
                                            
                                            gotAnswerFromGetProcesses(commandConstructor, globalCommandConstructor, addDraggedFiles);
                                        }
                                    },
                        error:      function(jqXHR, textStatus, errorThrown){
                                        //Handle any errors
                                        alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                    }
                    });
            }
    };
    
    /** Anonymous function that is called when a button with get preview of a command is clicked
     * @function
     * @name jQuery_click_btnShowCommandPreview
     */
    $('#btnShowCommandPreview').click(function() {
        var updatePreviewGraphAfterResponse = false;
        getCommandLinesPreview(clientCommandConstructor, updatePreviewGraphAfterResponse); 
    });
    
    /** Anonymous function that is called when create job button is clicked
     * @function
     * @name jQuery_click_btnSaveCommandsAsProcess
     */
    $('#btnSaveCommandsAsProcess').click(function() {
        var hiProcessType   = document.getElementById('hiProcessType');
        hiProcessType.value = 2; // this is read in the commandConstructor getProcessType function which is used when creating the new process
        storeCommandsAsProcess(clientCommandConstructor, hiProcessType.value); 
    });

    /** Anonymous function that is called when create template job button is clicked
     * @function
     * @name jQuery_click_btnSaveCommandsAsTemplate
     */
    $('#btnSaveCommandsAsTemplate').click(function() {
        var hiProcessType   = document.getElementById('hiProcessType');
        hiProcessType.value = 1;
        storeCommandsAsProcess(clientCommandConstructor, hiProcessType.value); 
    });

    /** storeCommandsAsProcess is called when commands is stored as either a job or a template 
     * @function
     * @name storeCommandsAsProcess
     * @param {CommandConstructor} commandConstructor commandConstructor is the global object that contains all information about the process that is going to be stored
     * @param {numeric} hiProcessTypeValue hiProcessTypeValue is a value that describes if the commands is going to be stored as either a template(hiProcessTypeValue==1) or a job (hiProcessTypeValue==2)
     */
    function storeCommandsAsProcess(commandConstructor, hiProcessTypeValue) {
        var url = $("#create_process_url").val();
        var data = createRun(commandConstructor);
        
        if(data != ''){
            $.ajax({
                        url:       url,
                        dataType: "json",
                        type:     "post",                        
                        data:       {
                                        json: data,
                                    },

                        success:    function( data ){
                                        if( $.isEmptyObject( data ) ){
                                            alert('some error occurred..');
                                        }
                                        else{
                                            /*{
                                                "steps": [
                                                    {
                                                        "step": 0,
                                                        "command": "SOMETHING"
                                                    },
                                                    {
                                                        "step": 1,
                                                        "command": "SOMETHING"
                                                    }
                                                ]
                                            }*/
                                            var commandlines = new Commandlines();
                                            if( ! $.isEmptyObject( data.steps ) ){
                                                $.each(data.steps, function(){
                                                    var commandline = new Commandline();
                                                    commandline.set(this.step, this.process_id, this.command);
                                                    commandlines.add(commandline);
                                                });
                                            }
                                            var title = hiProcessTypeValue == 2 ? 'Job inserted' : 'Template inserted';
                                            var c     = commandlines.commandline.length > 1 ? 'commands' : 'command';
                                            var msg   = hiProcessTypeValue == 2 ? 'A preview of the ' + c + ' that will be run.<br />' : 'A preview of the ' + c + ' that the template could produce.<br />'; 
                                            showDialog(msg + commandlines.getCommands(), title);
                                        }
                                    },
                        error:      function(jqXHR, textStatus, errorThrown)
                                    {
                                        //Handle any errors
                                        alert("jqXHR.responseText:" + jqXHR.responseText + "jqXHR:" + jqXHR + " textStatus:" + textStatus + " errorThrown" + errorThrown);
                                    }
            });
        }
    };
    
 });

