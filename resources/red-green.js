// behaviours for red-green app

function long_poll_d(serial) {
    rg_log("poll start, serial: ", serial)
    $.ajax({url: '/poll', cache: false, data: { q : serial }, dataType: "json", timeout: 180000,
            // server returned, update and start next call to server
            success: function(data) {
                poll_update(data)
                long_poll_d(data["serial"]+1)
                rg_log("poll success! [serial:", data["serial"], "]")
            },
            // assume call timed out, try again
            error: function() {
                rg_log("poll error!")
                setTimeout(function() { long_poll_d(serial) }, 500)
            }
           });
}

function set_status(status) {
    msg = "Status: "
    for (var i = 0; i < arguments.length; i++) {
        msg += arguments[i]
    }
    $('#status-title').text(msg)
}

function obj_to_s(obj) {
    list = []
    keys = Object.keys(obj)
    for (var i = 0; i < keys.length; i++) {
        list.push(keys[i] + ":'" + obj[keys[i]] + "'")
    }
    return list.join(' ')
}

function update_pylint(str) {
    panel = $('#pylint-panel')
    content = $('#pylint-content')
    if (str && str.length > 0) {
        content.html(str)
        panel.show()
    }
    else {
        panel.hide()
    }
}

function poll_update(data) {
    rg_log("poll update")
//    rg_log("data: ", obj_to_s(data))
    $('#git-content').text(data["git"])
    $('#stdout-content').text(data["stdout"])
    $('#status').text(data["status"])
    $('#error-content').text(data["error"])
    update_pylint(data["pylint"])
    status_panel = $('#status-panel')
    status_title = $('#status-title')
    error_panel  = $('#error-panel')
    panel_classes = [ "panel-green", "panel-red", "panel-default", "panel-yellow" ]
    panel_class = "Fail"
    status = data["status"]
    switch (data["status"]) {
    case "ok":
        panel_class = "panel-green"
        status = "Pass"
        error_panel.hide()
        break
    case "init":
        panel_class = "panel-default"
        status = "Init"
        error_panel.hide()
        break
    case "test_script_failed":
        panel_class = "panel-yellow"
        status = "Test Script Failed (see error panel)"
        error_panel.show()
        break
    default: // error
        panel_class = "panel-red"
        error_panel.show()
    }
    // set properties of page
    set_status(status, " [", data["status"], "]")
    status_panel.addClass(panel_class)
    for (var i = 0; i < panel_classes.length; i++) {
        if (panel_classes[i] != panel_class) {
            status_panel.removeClass(panel_classes[i])
        }
    }
}

// log message to javascript console as well as in page console
function rg_log() {
    log_div = $('#console-content')
    msg = (new Date().toUTCString()) + ": "
    for (var i = 0; i < arguments.length; i++) {
        msg += arguments[i]
    }
    msg += "\n"
    log_div.append(msg)
    console.log(msg)
}

function red_green_init(serial) {
    rg_log("red-green init.")
    long_poll_d(serial)
}

