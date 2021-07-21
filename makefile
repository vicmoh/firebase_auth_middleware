m=[AUTO]
git:
	git add -A
	git commit -m '$(m)'
	git push

new:
	git branch $(version); git checkout $(version); git push --set-upstream origin $(version); git checkout master;

install:
	cd ./rest/client; flutter packages get;
	npm install;

