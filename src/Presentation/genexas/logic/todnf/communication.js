// This will be in local.js: local to each kind of exercise
var exercisekind = "Proposition to DNF";
var id = 421;

/**
* functions to use the services in a straightforward way. 
* for each service, there is a calling function and a function that we be called back when the results are available.
 */
function generate() {
	ss_generate(5, handleGenerate);
}
function handleGenerate(state) {
	closeallhelp();
	clearFeedback();
	task = state.exercise;
	areas.exerciseArea.innerHTML = task;
	areas.workArea.value = task;
	areas.historyArea.innerHTML = task;
	newSnapshot(task, "", task, task, new CopyContent(state, ""), state, "");
}
 
function getReady() {
	ss_getReady(snapshot.state, handleReady);
}
function handleReady(solved) {
	closeallhelp();
	var feedbackArea = areas.feedbackArea;
	var expression = (snapshot.state).exercise;
	if (solved) {
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + yes + ", <strong>" + expression + "</strong> is " + ready + ".</p>";
	}
	else {
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + no + ", <strong>" + expression + "</strong> is <strong>" + not + "</strong> " + ready + ".</p>";
	}
	feedbackArea.scrollTop = feedbackArea.scrollHeight;
	addFeedback(feedbackArea.innerHTML);
}
 
function getHint() {
	ss_getHint("", snapshot.state, handleHint);
}
function handleHint(listOfRules) {
	closeallhelp();
	var feedbackArea = areas.feedbackArea;
	var expression = (snapshot.state).exercise;
	if (listOfRules.length > 0) {
		rules = writeArray(listOfRules);
		feedbackArea.innerHTML = feedbackArea.innerHTML  + "<p>" + applicable + " <strong>" + expression + "</strong>:<br><br><strong>" + rules + "</strong></p>";
	}
	else {
		feedbackArea.innerHTML = feedbackArea.innerHTML  + "<p>" + sorry + " <strong>" + expression + "</strong></p>";
	}
	feedbackArea.scrollTop = feedbackArea.scrollHeight;
	addFeedback(feedbackArea.innerHTML);
}


function getNext() {
	var feedbackArea = areas.feedbackArea;
	var workExpression = ((areas.workArea).value).htmlToAscii();
	if (workExpression != (((snapshot.state).exercise).htmlToAscii())) {
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + changed + "</p>";
		newSnapshot(snapshot.exercise, feedbackArea.innerHTML, snapshot.history, workExpression, snapshot.copy, snapshot.state, snapshot.location);
	}
	ss_getNext(snapshot.state, handleNext);
}
function handleNext(rule, location, state) {
	closeallhelp();
	var feedbackArea = areas.feedbackArea;
	var newExpression = (state.exercise).asciiToHtml() ;
	var expression = ((snapshot.state).exercise).asciiToHtml();
	if (rule) {
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + applicable + " <strong>" + expression + "</strong>:<br><br><strong>" + rule + "</strong> rule</p><p>" + resulting + " <strong>" + newExpression + "</strong></p><p>" + paste + "</p><p";
		var copyContent = new CopyContent(state, location);
		newSnapshot(snapshot.exercise, feedbackArea.innerHTML, snapshot.history, (areas.workArea).value.asciiToHtml(), copyContent, snapshot.state, snapshot.location);
	}
	else {
		feedbackArea.innerHTML = feedbackArea.innerHTML  + "<p>" + sorry + " <strong>" + expression + "</strong></p>";
		addFeedback(feedbackArea.innerHTML);
	}
	feedbackArea.scrollTop = feedbackArea.scrollHeight;
}

function getRemaining() {
	var feedbackArea = areas.feedbackArea;
	var workExpression = ((areas.workArea).value).htmlToAscii();
	if (workExpression != (((snapshot.state).exercise).htmlToAscii())) {
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + changed + "</p>";
		newSnapshot(snapshot.exercise, feedbackArea.innerHTML, snapshot.history, workExpression, snapshot.copy, snapshot.state, snapshot.location);
	}
	ss_getRemaining(snapshot.state, handleRemaining);
}
function handleRemaining(number) {
	closeallhelp();
	var feedbackArea = areas.feedbackArea;
	var expression = ((snapshot.state).exercise).asciiToHtml();
	feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + forexpression + " <strong>" + expression + "</strong>, " + minimum + " <br><strong>" + number + "</strong> " + steps + ".</p>";
	addFeedback(feedbackArea.innerHTML);
	feedbackArea.scrollTop = feedbackArea.scrollHeight;
}

function getFeedback() {
	var feedbackArea = areas.feedbackArea;
	var workExpression = ((areas.workArea).value).htmlToAscii();
	if (workExpression == (((snapshot.state).exercise).htmlToAscii())) {
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + unchanged + "</p>";
		newSnapshot(snapshot.exercise, feedbackArea.innerHTML, snapshot.history, workExpression, snapshot.copy, snapshot.state, snapshot.location);
	}
	else {
		ss_getFeedback(snapshot.state, workExpression, handleFeedback);
	}
}
function handleFeedback(result, rules, state) {
	closeallhelp();
	var feedbackArea = areas.feedbackArea;
	var historyArea = areas.historyArea;
	feedbackArea.innerHTML = feedbackArea.innerHTML + "<p><strong>" + result + "</strong></p>";
	if (result == "Ok") {
		historyArea.innerHTML = historyArea.innerHTML + "<br>" + (state.exercise).asciiToHtml();
		if (rules.length > 0) {
			feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + applied + "<strong>" + writeArray(rules) + "</strong></p></p>";
		}
		newSnapshot(snapshot.exercise, feedbackArea.innerHTML, historyArea.innerHTML, state.exercise, new CopyContent(state, snapshot.location), state, snapshot.location);
	}
	else if (result == "Detour") {
		historyArea.innerHTML = historyArea.innerHTML + "<br>" + expression.asciiToHtml();
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p><strong>" + two + "</strong></p></p>";
		if (rules.length > 0) {
			feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>applied" + writeArray(rules) + "</strong></p></p>";
		}
		newSnapshot(snapshot.exercise, feedbackArea.innerHTML, historyArea.innerHTML, state.exercise, new CopyContent(state, snapshot.location), state, snapshot.location);
	}
	else {
		feedbackArea.innerHTML = feedbackArea.innerHTML + "<p>" + copybutton +  "</p>";
		addFeedback(feedbackArea.innerHTML);
	}
	feedbackArea.scrollTop = feedbackArea.scrollHeight;
}