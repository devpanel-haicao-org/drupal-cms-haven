document.addEventListener("DOMContentLoaded", function() {
  var toggleBtn = document.getElementById('dp-toggle-btn');
  var detailsPanel = document.getElementById('dp-details-panel');

  if (toggleBtn && detailsPanel) {
    toggleBtn.addEventListener('click', function(e) {
      e.preventDefault();
      detailsPanel.classList.toggle('open');
      toggleBtn.classList.toggle('active');
    });
  }
});
