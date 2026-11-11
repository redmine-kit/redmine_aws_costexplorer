// The daily chart of the Cost Explorer tab, the only page that loads this
// file. Redmine draws charts only with its own Stimulus controllers, and none
// fits: reports--details draws horizontal bars of whole numbers with a title,
// and repositories--stats requests its data from the repository. This one is
// written after reports--details (app/javascript/controllers/reports/
// details_controller.js), with the data in the page and Redmine's Chart.js
// loaded lazily from the importmap, for vertical bars of amounts in the
// snapshot's currency.
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

// Connects to data-controller="aws-costexplorer--daily"
class DailyController extends Controller {
  static targets = ['labels', 'datasets', 'canvas']
  static values = { currency: String }

  connect() {
    const chartData = {
      labels:   jsonData(this.labelsTarget),
      datasets: jsonData(this.datasetsTarget)
    };
    // It is loaded lazily at runtime
    import('chart.js').then(chart =>
      this.renderChart(chart.default, chartData)
    );
  }

  renderChart(Chart, chartData) {
    // The colors of Redmine's repository statistics; estimated days are the
    // same blue, lighter.
    const backgroundColors = ['rgba(54, 162, 235, 0.7)', 'rgba(54, 162, 235, 0.2)'];
    const borderColors     = ['rgb(54, 162, 235)',       'rgb(54, 162, 235)'];
    chartData.datasets.forEach((dataset, i) => {
      dataset.backgroundColor = backgroundColors[i];
      dataset.borderColor     = borderColors[i];
      dataset.borderWidth     = 1;
    });
    const currency = this.currencyValue;
    new Chart(this.canvasTarget.getContext('2d'), {
      type: 'bar',
      data: chartData,
      options: {
        responsive: true,
        plugins: {
          // No title: the section's heading names the chart
          legend: {position: 'right'},
          tooltip: {
            callbacks: {
              label: (context) => `${context.dataset.label}: ${context.parsed.y.toFixed(2)} ${currency}`
            }
          }
        },
        scales: {
          x: {stacked: true},
          y: {stacked: true, beginAtZero: true, title: {display: true, text: currency}}
        }
      }
    });
  }
}

function jsonData(template) {
  return template.content ? JSON.parse(template.content.textContent) : []
}

application.register('aws-costexplorer--daily', DailyController)
