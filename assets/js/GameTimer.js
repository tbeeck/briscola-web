'use strict';

const GameTimer = {
  mounted() {
    this.start = 0;
    this.end = 0;
    this.handleEvent("timer", ({ deadline_start, deadline_end }) => {
      this.start = deadline_start;
      this.end = deadline_end;
    });
    let update = () => {
      let now = Date.now();
      if (now > this.end + 100) {
        return;
      }
      let percent = Math.min(
        1 - (this.end - Date.now()) / (this.end - this.start),
        1
      ) * 100;
      this.el.style.width = percent + "%";
    };
    setInterval(update, 20);
  }
}

export default GameTimer;