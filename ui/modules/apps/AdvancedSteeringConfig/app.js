angular.module("beamng.apps").directive("advancedSteeringConfig", [() => {
    return {
        templateUrl: "/ui/modules/apps/advancedSteeringConfig/app.html",
        replace: true,
        restrict: "EA",
        // require: "^bngApp",
        link: function (scope, element, attrs, ctrl) {
            scope.rootElement = element[0];

            scope.buttons = {
                applyButton:   null,
                saveButton:    null,
                defaultButton: null
            };

            scope.inputsByID = {};
            let allInputs    = scope.rootElement.querySelectorAll(".settings-container input");
            for (let em of allInputs) scope.inputsByID[em.id] = em;

            scope.currentSettings = {};

            scope.masterToggle  = scope.rootElement.querySelector(".settings-container #cfg-enableCustomSteering");
            scope.reloadWarning = scope.rootElement.querySelector(".settings-container #reload-warning");

            scope.escapeStr = (str) => {
                return (str + '').replace(/[\\"']/g, '\\$&').replace(/\u0000/g, '\\0');
            };

            scope.formatInput = (inputEm) => {
                let originalInput = inputEm.value;
                let alteredVal    = originalInput;
                if (inputEm.parentNode.classList.contains("input-format-degree")) {
                    alteredVal = `${alteredVal}°`;
                }
                if (inputEm.parentNode.classList.contains("input-format-offset")) {
                    if (parseFloat(originalInput) > 0) alteredVal = `+${alteredVal}`;
                }
                inputEm.parentNode.setAttribute("altered-value", alteredVal);
            };

            scope.updateGUIValues = (settings) => {
                for (let k in settings) {
                    let inputEm = scope.inputsByID[`cfg-${k}`];
                    if (inputEm) {
                        if (inputEm.type === "checkbox") inputEm.checked = settings[k];
                        else inputEm.value = settings[k];
                        scope.formatInput(inputEm);
                    }
                }
            };

            scope.readSettingsFromGUI = () => {
                let settings = {};
                for (let k in scope.inputsByID) {
                    let inputEm    = scope.inputsByID[k];
                    let val        = (inputEm.type === "checkbox") ? inputEm.checked : parseFloat(inputEm.value);
                    let name       = inputEm.id.replace(/^cfg-/, "");
                    settings[name] = val;
                }
                return settings;
            };

            scope.applySettings = () => {
                let settings = scope.readSettingsFromGUI();
                bngApi.engineLua(`advancedSteeringGE.applySettings('${JSON.stringify(settings)}')`);
            };

            scope.saveSettings = () => {
                let settings = scope.readSettingsFromGUI();
                bngApi.engineLua(`advancedSteeringGE.saveSettings('${JSON.stringify(settings)}')`);
            };

            scope.loadDefaultSettings = () => {
                bngApi.engineLua("advancedSteeringGE.displayDefaultSettings()");
            };

            scope.loadCurrentSettings = () => {
                bngApi.engineLua("advancedSteeringGE.displayCurrentSettings()");
            };

            scope.showFeedbackOnButton = (button, successText, success) => {
                let buttonText = button.querySelector("span");
                if (buttonText && !button.getAttribute("is-busy")) {
                    button.setAttribute("is-busy", true);
                    let originalText     = buttonText.innerText;
                    buttonText.innerText = (success) ? successText : "Error";
                    buttonText.style     = (success) ? "color: #00d26a" : "color: #FF0000";
                    setTimeout(() => {
                        buttonText.innerText = originalText;
                        buttonText.style     = "";
                        button.removeAttribute("is-busy");
                    }, 1500);
                }
            };

            scope.updateReloadWarning = (isDirty) => {
                if (isDirty === false) scope.reloadWarning.classList.add("hidden");
                else if (isDirty === true || scope.masterToggle.checked != scope.currentSettings["enableCustomSteering"]) scope.reloadWarning.classList.remove("hidden");
            };

            element.ready(() => {
                let formattedInputs = scope.rootElement.getElementsByClassName("formatted-input-container");

                for (let inputContainer of formattedInputs) {
                    let inputEm = inputContainer.querySelector("input");
                    inputEm.addEventListener("input", (evt) => scope.formatInput(evt.target));
                    scope.formatInput(inputEm);
                }

                scope.buttons.saveButton = scope.rootElement.querySelector(".footer-buttons #save-button");
                scope.buttons.saveButton.addEventListener("click", scope.saveSettings);

                scope.buttons.applyButton = scope.rootElement.querySelector(".footer-buttons #apply-button");
                scope.buttons.applyButton.addEventListener("click", scope.applySettings);

                scope.buttons.defaultButton = scope.rootElement.querySelector(".footer-buttons #default-button");
                scope.buttons.defaultButton.addEventListener("click", scope.loadDefaultSettings);

                scope.masterToggle.addEventListener("change", scope.updateReloadWarning);

                scope.loadCurrentSettings();
            });

            scope.$on("advancedSteeringSettingsApplied", (evt, success) => {
                scope.showFeedbackOnButton(scope.buttons.applyButton, "Applied!", success);
            });

            scope.$on("advancedSteeringSettingsSaved", (evt, success) => {
                scope.showFeedbackOnButton(scope.buttons.saveButton, "Saved!", success);
            });

            scope.$on("advancedSteeringSetDisplayedSettings", (evt, data) => {
                if (data["isDefault"]) scope.showFeedbackOnButton(scope.buttons.defaultButton, "Loaded!", true);
                else scope.currentSettings = data["settings"];
                scope.updateGUIValues(data["settings"]);
                scope.updateReloadWarning(data["dirty"]);
            });
        }
    };
}]);