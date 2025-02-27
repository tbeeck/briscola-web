"use strict";

const PlusPoints = {
  mounted() {
    this.handleEvent("points", ({ player, delta }) => {
      this.showPointGain(player, delta);
    });
  },

  showPointGain(player, points) {
    // Create element
    const pointsElement = document.createElement("div");
    pointsElement.textContent = points.toString();
    if (points >= 0) {
      pointsElement.textContent = "+" + pointsElement.textContent;
    }
    pointsElement.className = "points-indicator";

    // Add different classes based on point value
    if (points < 5) {
      pointsElement.classList.add("points-small");
    } else if (points < 10) {
      pointsElement.classList.add("points-medium");
    } else {
      pointsElement.classList.add("points-large");
    }

    const playerListRect = document
      .getElementById(`player-list-${player}`)
      .getBoundingClientRect();
    // Position where the points were earned
    pointsElement.style.left = playerListRect.x + playerListRect.width + "px";
    pointsElement.style.top =
      playerListRect.y + Math.floor(playerListRect.height / 4) + "px";
    this.el.appendChild(pointsElement);

    // Remove the element after animation completes
    setTimeout(() => {
      pointsElement.remove();
    }, 1500); // Same duration as the animation
  },
};

export default PlusPoints;
