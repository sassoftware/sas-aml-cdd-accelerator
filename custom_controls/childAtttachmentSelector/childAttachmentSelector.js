/*
 * ------------------------------------------------------------------------------------
 *   Copyright (c) SAS Institute Inc.
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
 * ---------------------------------------------------------------------------------------
 *
 */
// Nick Newbill, 2022
// Visual Investigator 10.7
//# sourceURL=childAttachmentSelector.js

(function () {
      angular.module("sngPageBuilderCustom")
	  .spbComponent("childAttachmentSelector", {
		 transclude: true,
         bindings: {
            childNode: "=",
            pageModel: "="
         },
		 template:
		         '<div class="spb-control-padding spb-page-control">' +
                 '    <select ng-model="itemSelection"' +
                 '            ng-options="item.name for item in ctrl.itemList track by item.id"' +
		 '            ng-change="checkSelection(itemSelection)">' +			 
                 '    </select>' +
                 '</div>',
         controller: childAttachmentSelectorCtrl
      });

	childAttachmentSelectorCtrl.$inject = ["spbCustomControlUtilsService","$element","$transclude","$scope", "$rootScope","$http","spbUrlStringBuilder","pageViewerConfig"];

    function childAttachmentSelectorCtrl(spbCustomControlUtilsService, $element, $transclude, $scope, $rootScope, $http, spbUrlStringBuilder, pageViewerConfig) {
        var ctrl = this;
	    console.log("...childAttachmentSelector Initiated");
	    //console.log(ctrl);
	    $scope.ctrl = ctrl;
	    this.$http = $http;
	    this.spbUrlStringBuilder = spbUrlStringBuilder;
	    this.pageViewerConfig = pageViewerConfig; 

        // Component Initialization
	    ctrl.$onInit = function() {
		    ctrl.entity_type = ctrl.pageModel.parent.type;
		    ctrl.entity_id = ctrl.pageModel.parent.data[ctrl.childNode.typeAttributes.entityID];

            // As form selection changes - update attributes that are written to pageModel and DB
			$scope.checkSelection = function() {
				//console.log("...Attachment Selection:" + $scope.itemSelection.name);
				ctrl.attachmentID = ctrl.childNode.typeAttributes.attachmentID;
				ctrl.attachmentName = ctrl.childNode.typeAttributes.attachmentName;

				if(ctrl.attachmentID){
					ctrl.pageModel.data[ctrl.childNode.typeAttributes.attachmentID] = $scope.itemSelection.id;
					ctrl.pageModel.data[ctrl.childNode.typeAttributes.attachmentName] = $scope.itemSelection.name;
				}
			}
			
			// Check existing entry for edit screens
			if (ctrl.pageModel.data[ctrl.childNode.typeAttributes.attachmentID]) {
			    $scope.itemSelection = {id: ctrl.pageModel.data[ctrl.childNode.typeAttributes.attachmentID], name: ctrl.pageModel.data[ctrl.childNode.typeAttributes.attachmentName]};
			    //console.log(ctrl.itemSelection);
				
			}

            // Query attachments and parse array list
		    if (ctrl.entity_id) {
				ctrl.url = "";
			    ctrl.url = "/svi-datahub/documents/" + ctrl.entity_type + "/" + ctrl.entity_id + "/attachments?start=0&limit=1000";
			    $http.get(ctrl.url)
			        .then(function successCallback(response) {
				        jsonString = JSON.stringify(response.data);
				        //console.log(jsonString);
					jsonParse = JSON.parse(jsonString);
					ctrl.itemList = jsonParse.items;
					//console.log(ctrl.itemList);
				    });
			};		
	    };
	};
})();
