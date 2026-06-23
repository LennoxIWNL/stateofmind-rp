var close = true;
$(document).ready(function () {
  window.addEventListener("message", function (event) {
    if (event.data.action == "openmenu") {
      CloseMenu(false);
      $("body").css("display", "block");
      if (event.data.typ == "mainmenu") {
        $(".mainmenu").css("display", "block");
      } else if (event.data.typ == "progressbar") {
        $(".progressbar").css("display", "block");
      } else {
        $(".tweetmenu").css("display", "block");
      }
    } else if (event.data.action == "tweettext") {
      $(".twitte-title").html("&lt;/&gt;" + event.data.text + "&lt;/&gt;");
    } else if (event.data.action == "close") {
      CloseMenu(true);
    } else if (event.data.action == "addMain") {
      $(".num").html(event.data.mylvl);
      html =
        `         
       <div class="item" onclick="ClickMain(this.id)" id ="` +
        event.data.id +
        `">
        <div class="top">
          <div class="item-title">
            &lt;/&gt; ` +
        event.data.name +
        ` &lt;/&gt;
            <t>` +
        event.data.money +
        `$</t>
          </div>
          <div class="item-level">` +
        event.data.lvl +
        ` LVL</div>
        </div>
        <div class="item-desc font-source">
        ` +
        event.data.dec +
        `
        </div>
      </div>
`;
      $(".items").prepend(html);
    } else if (event.data.action == "notification") {
      if (event.data.myx == "error") {
        Swal.fire({
          icon: "error",
          title: "Oops...",
          text: event.data.text,
          background: "rgba(1, 4, 6, 0.5)",
          width: 400,
          iconColor: "white",
          confirmButtonColor: "rgba(108, 255, 176, 0.52)",
          confirmButtonText: "Okey, I got it!",
          color: "white",
        });
      } else {
        Swal.fire({
          icon: "success",
          title: "Success...",
          text: event.data.text,
          background: "rgba(1, 4, 6, 0.5)",
          width: 400,
          iconColor: "white",
          confirmButtonColor: "rgba(108, 255, 176, 0.52)",
          confirmButtonText: "Okey, I got it!",
          color: "white",
        });
      }
    } else if (event.data.action == "WaitScreen") {
      CloseMenu(false);
      $("body").css("display", "block");
      $(".progressbar").css("display", "block");
      hackAnimation(".terminal-codes", 500, 12, "$ "); // @, # >>, $, >>, //, \\, %, -, _, {}, [], (), *, ->
      updateProgressBar(event.data.time);
    } else if (event.data.action == "FinishText") {
      if (event.data.typ == "text") {
        $(".form-input y").html(event.data.rtrn);
      } else if (event.data.typ == "table") {
        $(".search-userlist").css("display", "block");
      }
    } else if (event.data.action == "addPlayer") {
      html =
        `         
      <li class="search-name" onclick="SelectSearch(this.id)" id="` +
        event.data.identifier +
        `">` +
        event.data.namex +
        `</li>
`;
      $(".search-list").prepend(html);
    } else if (event.data.action == "removePlayer") {
      if (event.data.typ == "cctv") {
        $(".search-input").css("display", "none");
      } else {
        $(".search-input").css("display", "block");
      }
      $(".search-list").empty();
    }
  });
});

$(document).on("keydown", function (event) {
  switch (event.keyCode) {
    case 27:
      CloseMenu(true);
  }
});

function CloseMenu(xx) {
  if (close) {
    $("body").css("display", "none");
    $(".progressbar").css("display", "none");
    $(".tweetmenu").css("display", "none");
    $(".mainmenu").css("display", "none");
    $(".search-input").css("display", "block");
    $(".search-userlist").css("display", "none");
    $(".form-input y").html("Awaiting Data...");
    if (xx) {
      $(".items").empty();
      $.post("https://BakiTelli_hackermenu/close");
    }
  }
}

function ClickMain(id) {
  $.post(
    "https://BakiTelli_hackermenu/ClickMain",
    JSON.stringify({
      id: id,
    })
  );
}

function MainPage() {
  if (close) {
    CloseMenu(true);
    $.post("https://BakiTelli_hackermenu/open");
  }
}

function Search() {
  $.post(
    "https://BakiTelli_hackermenu/Search",
    JSON.stringify({
      text: $("#nameinput").val(),
    })
  );
  $("#nameinput").val("");
}

function SelectSearch(id) {
  $.post(
    "https://BakiTelli_hackermenu/SelectSearch",
    JSON.stringify({
      id: id,
    })
  );
}

function SendTweet() {
  $.post(
    "https://BakiTelli_hackermenu/SendTweet",
    JSON.stringify({
      text: $(".twitte-input").val(),
    })
  );
  $(".twitte-input").val("");
  CloseMenu(true);
}

function updateProgressBar(m) {
  let progress = 0;
  close = false;
  const updateInterval = 1000;
  const totalTime = m * 1000; // Toplam süre (milisaniye cinsinden)
  const progressIncrement = 100 / (totalTime / updateInterval); // İlerleme yüzdesi artışı
  const timer = setInterval(() => {
    progress += Math.floor(progressIncrement);
    $(".progress").attr("percent", progress);
    updateProgressBarx();
    if (progress >= 100) {
      close = true;
      $(".search-userlist").css("display", "none");
      $.post("https://BakiTelli_hackermenu/Finish");
      clearInterval(timer);
    }
  }, updateInterval);
}
function updateProgressBarx() {
  var jQ = (elm) => document.querySelector(elm);

  jQ(".progress-bar .bar").style.width = jQ(
    ".progress .percent"
  ).innerHTML = `${Math.max(
    0,
    Math.min(100, +jQ(".progress").getAttribute("percent") || 25)
  )}%`;
}
