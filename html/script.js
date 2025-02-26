window.addEventListener("message", (event) => {
    const data = event.data;

    if (data.action === "showFlasher") {
        const flasher = document.getElementById(`flasher-${data.direction}`);
        flasher.style.display = "block";
    }

    if (data.action === "hideFlasher") {
        document.querySelectorAll(".flasher").forEach(flasher => {
            flasher.style.display = "none";
        });
    }
});
