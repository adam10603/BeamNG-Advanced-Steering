angular.module("beamng.apps").directive("advancedSteeringConfig", [() => {
    return {
        templateUrl: "/ui/modules/apps/advancedSteeringConfig/app.html",
        replace: true,
        restrict: "EA",
        // require: "^bngApp",
        link: function (scope, element, attrs, ctrl) {
            scope.rootElement = element[0];

            scope.buttons = {
                applyButton:      null,
                saveButton:       null,
                presetLoadButton: null,
                presetSaveButton: null
            };

            scope.inputsByID = {};
            let allInputs    = scope.rootElement.querySelectorAll(".settings-container input");
            for (let em of allInputs) scope.inputsByID[em.id] = em;

            scope.savedSettings = {};
            scope.storedToggleVal = true;
            scope.requestedSave = {};

            scope.masterToggle   = scope.rootElement.querySelector(".settings-container #cfg-enableCustomSteering");
            scope.reloadWarning  = scope.rootElement.querySelector(".settings-container #reload-warning");

            scope.presetDropdown = scope.rootElement.querySelector(".settings-container #ui-preset-dropdown");

            scope.escapeStr = (str) => {
                return (str + '').replace(/[\\"']/g, '\\$&').replace(/\u0000/g, '\\0');
            };

            scope.showFeedbackOnButton = (button, successText, failureText, success) => {
                let buttonText = button.querySelector("span");
                if (buttonText && !button.getAttribute("is-busy")) {
                    button.setAttribute("is-busy", true);
                    let originalText     = buttonText.innerText;
                    buttonText.innerText = (success) ? successText : failureText;
                    buttonText.style     = (success) ? "color: #00d26a" : "color: #FF0000";
                    setTimeout(() => {
                        buttonText.innerText = originalText;
                        buttonText.style     = "";
                        button.removeAttribute("is-busy");
                    }, 1500);
                }
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

            scope.checkForDummyPreset = (buttonPressed) => {
                if (scope.presetDropdown.options[scope.presetDropdown.selectedIndex].getAttribute("dummy")) {
                    scope.showFeedbackOnButton(buttonPressed, "", "Pick one!", false);
                    return true;
                }
                return false;
            };

            scope.checkForReadOnlyPreset = () => {
                if (scope.presetDropdown.options[scope.presetDropdown.selectedIndex].getAttribute("readonly")) {
                    scope.showFeedbackOnButton(scope.buttons.presetSaveButton, "", "Read-only", false);
                    return true;
                }
                return false;
            };

            scope.loadPreset = () => {
                if (scope.checkForDummyPreset(scope.buttons.presetLoadButton)) return;
                bngApi.engineLua(`advancedSteeringGE.displayPreset('${scope.presetDropdown.value}')`);
            };

            scope.savePreset = () => {
                if (scope.checkForDummyPreset(scope.buttons.presetSaveButton)) return;
                if (scope.checkForReadOnlyPreset()) return;
                let settings = scope.readSettingsFromGUI();
                bngApi.engineLua(`advancedSteeringGE.savePreset('${JSON.stringify(settings)}', '${scope.presetDropdown.value}')`);
            };

            scope.applySettings = () => {
                let settings = scope.readSettingsFromGUI();
                bngApi.engineLua(`advancedSteeringGE.applySettings('${JSON.stringify(settings)}')`);
            };

            scope.saveSettings = () => {
                let settings = scope.readSettingsFromGUI();
                scope.requestedSave = settings;
                bngApi.engineLua(`advancedSteeringGE.saveSettings('${JSON.stringify(settings)}')`);
            };

            scope.loadCurrentSettings = () => {
                bngApi.engineLua("advancedSteeringGE.displayCurrentSettings()");
            };

            scope.loadPresetList = () => {
                bngApi.engineLua("advancedSteeringGE.displayPresetList()");
            };

            // scope.refreshPresetList = () => {
            //     bngApi.engineLua("advancedSteeringGE.refreshPresetList()");
            // };

            scope.updateReloadWarning = (isDirty) => {
                if (isDirty === false) scope.reloadWarning.classList.add("hidden");
                else if (isDirty === true || scope.masterToggle.checked != scope.storedToggleVal) scope.reloadWarning.classList.remove("hidden");
            };

            scope.checkUnsavedValues = () => {
                for (let k in scope.savedSettings) {
                    let inputEm = scope.inputsByID[`cfg-${k}`];
                    if (inputEm) {
                        let inputEmClassList = inputEm.parentElement.querySelector(".unsaved-indicator").classList;
                        let inputEmVal = (inputEm.type === "checkbox" ? inputEm.checked : inputEm.value);
                        if (inputEmVal != scope.savedSettings[k]) inputEmClassList.remove("hidden");
                        else inputEmClassList.add("hidden");
                    }
                }
            };

            scope.addPresetToDropdown = (preset) => {
                if (preset.dummy) {
                    angular.element(scope.presetDropdown).append(angular.element(
                        `<option value="${preset.ID}" dummy="true">${preset.name}</option>`
                    ));
                } else {
                    angular.element(scope.presetDropdown).append(angular.element(
                        `<option value="${preset.ID}" ${(preset.readOnly ? "readonly=\"true\"" : "")}>${(preset.readOnly ? "🔒 " : "")}${preset.name}</option>`
                    ));
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

                scope.buttons.presetLoadButton = scope.rootElement.querySelector(".preset-buttons #preset-load-button");
                scope.buttons.presetLoadButton.addEventListener("click", scope.loadPreset);

                scope.buttons.presetSaveButton = scope.rootElement.querySelector(".preset-buttons #preset-save-button");
                scope.buttons.presetSaveButton.addEventListener("click", scope.savePreset);

                scope.masterToggle.addEventListener("change", scope.updateReloadWarning);

                scope.rootElement.querySelectorAll("button").forEach((em) => {
                    em.addEventListener("click", (e) => e.target.blur());
                });

                scope.rootElement.querySelectorAll("select").forEach((em) => {
                    em.addEventListener("focus",  (e) => e.target.size = 5);
                    em.addEventListener("blur",   (e) => e.target.size = 1);
                    em.addEventListener("change", (e) => e.target.blur());
                });

                scope.loadCurrentSettings();
                scope.loadPresetList();
            });

            scope.$on("advancedSteeringSettingsApplied", (evt, success) => {
                scope.showFeedbackOnButton(scope.buttons.applyButton, "Applied!", "Error", success);
            });

            scope.$on("advancedSteeringSettingsSaved", (evt, success) => {
                scope.savedSettings = Object.assign({}, scope.requestedSave);
                scope.showFeedbackOnButton(scope.buttons.saveButton, "Saved!", "Error", success);
            });

            scope.$on("advancedSteeringPresetSaved", (evt, success) => {
                scope.showFeedbackOnButton(scope.buttons.presetSaveButton, "Stored!", "Error", success);
            });

            scope.$on("advancedSteeringSetDisplayedSettings", (evt, data) => {
                if (data["preset"]) scope.showFeedbackOnButton(scope.buttons.presetLoadButton, "Loaded!", "Error", !!data["settings"]);
                else scope.storedToggleVal = !!data["settings"]["enableCustomSteering"];
                if (data["saved"]) scope.savedSettings = data["settings"];
                scope.updateGUIValues(data["settings"]);
                scope.updateReloadWarning(data["dirty"]);
            });

            scope.$on("advancedSteeringDisplayPresetList", (evt, data) => {
                if (!Array.isArray(data)) return;
                scope.presetDropdown.innerHTML = "";
                scope.addPresetToDropdown({
                    ID: "dummy",
                    name: "[None]",
                    readOnly: true,
                    dummy: true
                });
                data.forEach(scope.addPresetToDropdown);
            });

            scope.$on("$destroy", () => {
                if (scope.unsavedCheckIntervalHandle !== -1) clearInterval(scope.unsavedCheckIntervalHandle);
            });

            scope.unsavedCheckIntervalHandle = setInterval(() => scope.checkUnsavedValues(), 250);
        }
    };
}]);