.PHONY: build app run install clean

build:
	swift build

app:
	scripts/build-app.sh

universal:
	scripts/build-app.sh --universal

run: app
	-pkill -x MenuNotes
	open build/MenuNotes.app

install: app
	-pkill -x MenuNotes
	rm -rf /Applications/MenuNotes.app
	cp -R build/MenuNotes.app /Applications/
	open /Applications/MenuNotes.app

clean:
	rm -rf .build build
