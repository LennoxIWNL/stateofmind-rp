var Scane_Show = false
var allowMove = false
var Player = 0
var selections = [];
var Not_Finger = false

$('.home-button').click(function() {
    if (allowMove) {
        var popup = new Audio('sounds/click.wav');
        popup.volume = 0.1;
        popup.play();
        if ($(this).attr('id') == 'scan_back') {
            $.post("https://" + GetParentResourceName() + "/closeUI",
            JSON.stringify(true))
        }
        $('.history-screen').css('display', 'none')
        $('.new-scan-screen').css('display', 'none')
        $('.information-screen').css('display', 'none')
        $('.welcome-screen').css('display', 'flex').hide().fadeIn(100)
        $('#progressBar').hide()
        Scane_Show = false
    }
})


$('.new_scan').click(function() {
    if (allowMove) {
        var popup = new Audio('sounds/click.wav');
        popup.volume = 0.1;
        popup.play();
        $.post("https://" + GetParentResourceName() + "/giveScan")
    }
})


$('.view_history').click(function() {
    if (allowMove) {
        var popup = new Audio('sounds/click.wav');
        popup.volume = 0.1;
        popup.play();
        $('.welcome-screen').fadeOut(150, function() {
            $('.history-screen').css('display', 'flex').hide().fadeIn(150)
        })
        var history = "";
        for (var i = 0; i < selections.length; i++) {
        history += "<div class='history-info-content'>" +
            "<span>" + (selections[i].firstName) + "</span>" +
            "<div class='bn33' history-tab=" + (i + 1) +">View</div>" +
            "</div>";
        }
        $(".history-player-info").html("<div class='report-title'>History</div>" + history);
    }
})


$(document).on('click', '.bn33', function() {
    if (allowMove) {
        var popup = new Audio('sounds/click.wav');
        popup.volume = 0.1;
        popup.play();
        var historyTabId = $(this).attr('history-tab');
        var selection = selections[historyTabId-1];
        $('.history-screen').fadeOut(150, function() {
            $('.information-screen').css('display', 'flex').hide().fadeIn(250)
        })
        if (!Not_Finger) {
            $('#id').text(selection.finger);
        }
        $('#first-name').text(selection.firstName);
        $('#last-name').text(selection.lastName);
        $('#dob').text(selection.dob);
        $('#gender').text(selection.gender);
    }
});


$('.clear-button').click(function() {
    if (allowMove) {
        var popup = new Audio('sounds/click.wav');
        popup.volume = 0.1;
        popup.play();
        $('.history-info-content').remove();
        selections = [];
    }
})



$('.scanner-image').click(function() {
    if ($('.new-scan-screen').is(':visible') && Scane_Show) {
        var popup = new Audio('sounds/scan.wav');
        popup.volume = 0.3;
        popup.play();
        Scane_Show = false
        $.post("https://" + GetParentResourceName() + "/scanFinger",
        JSON.stringify({pID: Player}))
    }
})

function Close() {
    Scane_Show = false
    allowMove = false
    Player = 0
    $('.container').fadeOut(250)
    $('.welcome-screen').css('display', 'flex')
    $('.history-screen').css('display', 'none')
    $('.new-scan-screen').css('display', 'none')
    $('.information-screen').css('display', 'none')
    $('#progressBar').hide()
    $.post("https://" + GetParentResourceName() + "/closeUI")
}


function LanguageAdd(data) {
    $('.welcome-text-1').text(data.welcome_txt)
    $('.FSD-title').text(data.department_txt)
    $('.new_scan').text(data.new_scan)
    $('.view_history').text(data.view_history)
    $('.finger-print-text').text(data.scaning_txt)
    $('.report-title').text(data.report_head)
    $('.history_head').text(data.report_head)
}


$(document).ready(function () {
    window.addEventListener("message", function (event) {
      switch (event.data.action) {
        case "openUI":
            Scane_Show = false
            LanguageAdd(event.data.language)
            $('.container').css('display', 'flex').hide().fadeIn(250)
            $('.home-button').show()
            allowMove = event.data.move
            break;
        case 'scanFinger': 
            Scane_Show = false
            $('#progressBar').show()
            $('.home-button').hide()
            if (!event.data.showFingerID && !Not_Finger) {
                $('#id').hide()
                $('div.info-content:first').removeClass('info-content');
                Not_Finger = true
            }
            var duration = event.data.time;
            $('#progressBar span').css('animation-duration', duration + 'ms').one('animationend', function() {
                var pData = event.data.data
                if (!allowMove) {
                    Close()
                } else {
                    $('#progressBar').hide()
                    $('.home-button').show()
                    $('.new-scan-screen').fadeOut(150, function() {
                        $('.information-screen').css('display', 'flex').hide().fadeIn(250)
                    })
                    if (!Not_Finger) {
                        $('#id').text(pData.finger);
                    }
                    $('#first-name').text(pData.firstname);
                    $('#last-name').text(pData.lastname);
                    $('#dob').text(pData.dob);
                    $('#gender').text(pData.gender);

                    var popup = new Audio('sounds/result.wav');
                    popup.volume = 0.2;
                    popup.play();


                    var id = selections.length + 1;
                    var playerInfo = {
                        id: "history-" + id,
                        finger: pData.finger,
                        firstName: pData.firstname,
                        lastName: pData.lastname,
                        dob: pData.dob,
                        gender: pData.gender
                    };
                    selections.push(playerInfo);
                    if (selections.length > 5) {
                        selections = selections.slice(-5);
                    }
                }
            });
            break;
        case 'giveScan':
            $('.container').css('display', 'flex')
            $('.welcome-screen').fadeOut(150, function() {
                $('.new-scan-screen').css('display', 'flex').hide().fadeIn(250)
            })
            Player = event.data.move
            Scane_Show = true
            break;
        case "close":
            Close();
      }
    });
});


$(document).on("keydown", function (event) {
    switch (event.keyCode) {
        case 27: // ESC
            Close();
            break;
        case 9: // ESC
            Close();
            break;
    }
});