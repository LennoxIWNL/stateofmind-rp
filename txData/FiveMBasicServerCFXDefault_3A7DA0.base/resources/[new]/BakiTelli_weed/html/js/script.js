$(document).ready(function () {
  window.addEventListener("message", function (event) {
    dt = event.data;
    if (dt.action == "OpenMenu") {
      $("body").css("display", "block");
      $("body").css("opacity", "1");

      $("#growth").css("width", dt.growth + "%");
      $("#health").css("width", dt.health + "%");
      $("#water").css("width", dt.water + "%");
      $("#fertilizer").css("width", dt.fertilizer + "%");
    } else if (dt.action == "Close") {
      closex();
    }
  });
});

$(document).on("keydown", function (event) {
  switch (event.keyCode) {
    case 27: // ESC
      closex();
  }
});

function closex() {
  $("body").animate({ opacity: "0" });
  setTimeout(function () {
    $("body").css("display", "none");
  }, 1500);
  $.post("https://BakiTelli_weed/close");
}

function Give(idx) {
  $.post(
    "https://BakiTelli_weed/Give",
    JSON.stringify({
      idx: idx,
    })
  );
}
