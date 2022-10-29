angular.module("beamng.apps").directive("arcadeSteering", [() => {
    return {
        templateUrl: "/ui/modules/apps/arcadeSteering/app.html",
        replace: true,
        restrict: "EA",
        // require: "^bngApp",
        link: function (scope, element, attrs, ctrl) {
            scope.rootElement = element[0];

            let cfg = {};

            scope.buttons = {
                applyButton:   null,
                saveButton:    null,
                defaultButton: null
            };

            scope.inputsByID = {};
            let allInputs    = scope.rootElement.querySelectorAll(".settings-container input");
            for (let em of allInputs) scope.inputsByID[em.id] = em;

            scope.masterToggle  = scope.rootElement.querySelector(".settings-container #cfg-enableCustomSteering");
            scope.reloadWarning = scope.rootElement.querySelector(".settings-container #reload-warning");

            scope.escapeStr = (str) => {
                return (str + '').replace(/[\\"']/g, '\\$&').replace(/\u0000/g, '\\0');
            };

            scope.vehicleCommand = (cmd) => {
                return `local veh = be:getPlayerVehicle(0) if veh then veh:queueLuaCommand("${scope.escapeStr(cmd)}") end`;
            };

            scope.formatInput = (inputEm) => {
                if (inputEm.parentNode.classList.contains("input-format-degree")) {
                    inputEm.parentNode.setAttribute("altered-value", `${inputEm.value}°`);
                }
            };

            scope.updateGUIValues = () => {
                for (let k in cfg) {
                    let inputEm = scope.inputsByID[`cfg-${k}`];
                    if (inputEm) {
                        if (inputEm.type === "checkbox") inputEm.checked = cfg[k];
                        else inputEm.value = cfg[k];
                        scope.formatInput(inputEm);
                    }
                }
            };

            scope.readSettingsFromGUI = () => {
                for (let k in scope.inputsByID) {
                    let inputEm = scope.inputsByID[k];
                    let val     = (inputEm.type === "checkbox") ? inputEm.checked : parseFloat(inputEm.value);
                    let name    = inputEm.id.replace(/^cfg-/, "");
                    cfg[name]   = val;
                }
            };

            scope.applySettings = () => {
                scope.readSettingsFromGUI();
                bngApi.engineLua(scope.vehicleCommand(`arcadeSteering.applySettings('${JSON.stringify(cfg)}')`));
            };

            scope.saveSettings = () => {
                scope.readSettingsFromGUI();
                bngApi.engineLua(scope.vehicleCommand(`arcadeSteering.saveSettings('${JSON.stringify(cfg)}')`));
            };

            scope.loadDefaults = () => {
                bngApi.engineLua(scope.vehicleCommand(`arcadeSteering.displayDefaultSettings()`));
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

            scope.updateReloadWarning = () => {
                if (scope.masterToggle.checked != cfg["enableCustomSteering"]) {
                    scope.reloadWarning.classList.remove("hidden");
                } else {
                    scope.reloadWarning.classList.add("hidden");
                }
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
                scope.buttons.defaultButton.addEventListener("click", scope.loadDefaults);

                scope.masterToggle.addEventListener("change", scope.updateReloadWarning);

                bngApi.engineLua(scope.vehicleCommand("arcadeSteering.displayCurrentSettings()"));
            });

            scope.$on("arcadeSteeringSettingsApplied", (evt, success) => {
                scope.showFeedbackOnButton(scope.buttons.applyButton, "Applied!", success);
            });

            scope.$on("arcadeSteeringSettingsSaved", (evt, success) => {
                scope.showFeedbackOnButton(scope.buttons.saveButton, "Saved!", success);
            });

            scope.$on("arcadeSteeringSetDisplayedSettings", (evt, data) => {
                cfg = data[0];
                scope.updateGUIValues();
                if (data[1]) scope.showFeedbackOnButton(scope.buttons.defaultButton, "Loaded!", true);
            });

            scope.$on("arcadeSteeringResetSettingsGUI", (evt) => {
                scope.updateReloadWarning();
            });
        }
    };
}]);