// The plugin's JSON (AwsCostexplorerController): the path the tab reads, and the shape of its answer.

export const costPaths = {
  /** GET: the tab (the latest stored costs; the page never calls Cost Explorer) */
  costs: '/admin/aws/costexplorer.json',
};

/** A row of costs per period, the amounts formatted by the server ("1,234.57 USD", "-"). */
export interface CostRow {
  name: string;
  this_month: string;
  previous_month: string;
}

export interface CostsJson {
  currency: string;
  totals: {
    this_month: string;
    /** the forecast, or null with the reason in no_forecast */
    forecast: string | null;
    no_forecast: string | null;
    previous_month: string;
    /** Cost Explorer hasn't finalized last month yet: 推定 */
    previous_estimated: boolean;
  };
  services: (CostRow & { details: CostRow[] })[];
  /** newest first */
  daily: { date: string; amount: string; estimated: boolean }[];
  /** the chart of the days, oldest first: the final costs and the estimated ones (Redmine's page's Chart.js data) */
  chart: { labels: string[]; datasets: { label: string; data: (number | null)[] }[] } | null;
  tag: { key: string; label: string; no_data: boolean; rows: CostRow[] } | null;
}

/** GET /admin/aws/costexplorer.json (AwsCostexplorerHelper#aws_costexplorer_json) */
export interface CostexplorerJson {
  /** REDMINE_COSTEXPLORER_ENABLED is true */
  enabled: boolean;
  /** the last fetch failed: its text (the class of the error only), and the network's advice when it was unreachable */
  failure: { text: string; unreachable: string | null } | null;
  /** a fetch running: 「更新: 実行中 (… から)」 */
  pending: string | null;
  /** when the costs were read */
  updated: string | null;
  costs: CostsJson | null;
}
