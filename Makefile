APP = Links
BUNDLE_ID = io.serhiy.$(APP)

BUILD_PATH = $(PWD)/build
APP_PATH = "$(BUILD_PATH)/$(APP).app"
ZIP_PATH = "$(BUILD_PATH)/$(APP).zip"

.SILENT: archive notarize sign prepare-dmg prepare-dSYM clean next-version
.PHONY: build archive notarize sign prepare-dmg prepare-dSYM clean next-version

build: clean next-version archive notarize sign prepare-dmg prepare-dSYM open

# --- MAIN WORLFLOW FUNCTIONS --- #

archive: clean
	osascript -e 'display notification "Exporting application archive..." with title "Build the Stats"'
	echo "Exporting application archive..."

	xcodebuild \
  		-scheme $(APP) \
  		-destination 'platform=OS X,arch=x86_64' \
  		-configuration Release archive \
  		-archivePath $(BUILD_PATH)/$(APP).xcarchive

	echo "Application built, starting the export archive..."

	xcodebuild -exportArchive \
  		-exportOptionsPlist "$(PWD)/exportOptions.plist" \
  		-archivePath $(BUILD_PATH)/$(APP).xcarchive \
  		-exportPath $(BUILD_PATH)

	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)

	echo "Project archived successfully"

notarize:
	osascript -e 'display notification "Submitting app for notarization..." with title "Build the $(APP)"'
	echo "Submitting app for notarization..."

	xcrun notarytool submit --keychain-profile "AC_PASSWORD" --wait $(ZIP_PATH)

	echo "$(APP) successfully notarized"

sign:
	osascript -e 'display notification "Stampling the $(APP)..." with title "Build the $(APP)"'
	echo "Going to staple an application..."

	xcrun stapler staple $(APP_PATH)
	spctl -a -t exec -vvv $(APP_PATH)

	osascript -e 'display notification "$(APP) successfully stapled" with title "Build the $(APP)"'
	echo "$(APP) successfully stapled"

prepare-dmg:
	if [ ! -d $(PWD)/create-dmg ]; then \
	    git clone https://github.com/create-dmg/create-dmg; \
	fi

	./create-dmg/create-dmg \
	    --volname $(APP) \
	    --background "./$(APP)/background.png" \
	    --window-pos 200 120 \
	    --window-size 500 320 \
	    --icon-size 80 \
	    --icon "$(APP).app" 125 175 \
	    --hide-extension "$(APP).app" \
	    --app-drop-link 375 175 \
	    --no-internet-enable \
	    $(PWD)/$(APP).dmg \
	    $(APP_PATH)

	rm -rf ./create-dmg

prepare-dSYM:
	echo "Zipping dSYMs..."
	cd $(BUILD_PATH)/$(APP).xcarchive/dSYMs && zip -r $(PWD)/dSYMs.zip .
	echo "Created zip with dSYMs"

# --- HELPERS --- #

clean:
	rm -rf $(BUILD_PATH)
	if [ -a $(PWD)/dSYMs.zip ]; then rm $(PWD)/dSYMs.zip; fi;
	if [ -a $(PWD)/$(APP).dmg ]; then rm $(PWD)/$(APP).dmg; fi;

next-version:
	versionNumber=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$(PWD)/$(APP)/Info.plist") ;\
	echo "Actual version is: $$versionNumber" ;\
	versionNumber=$$((versionNumber + 1)) ;\
	echo "Next version is: $$versionNumber" ;\
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$versionNumber" "$(PWD)/$(APP)/Info.plist" ;\

open:
	osascript -e 'display notification "$(APP) signed and ready for distribution" with title "Build the $(APP)"'
	echo "Opening working folder..."
	open $(PWD)