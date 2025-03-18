"use strict";

const GameTimer = {
  mounted() {
    this.start = 0;
    this.end = 0;
    this.handleEvent("timer", ({ end }) => {
      this.start = Date.now();
      this.end = new Date(end * 1000);
    });
    let update = () => {
      let now = Date.now();
      if (now > this.end + 100) {
        return;
      }
      let percent =
        Math.min(1 - (this.end - Date.now()) / (this.end - this.start), 1) *
        100;
      this.el.style.width = percent + "%";
    };
    this.interval = setInterval(update, 10);
  },

  destroyed() {
    clearInterval(this.interval);
  },
};

export default GameTimer;
