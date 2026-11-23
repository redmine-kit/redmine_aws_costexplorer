import type { CostexplorerJson } from './api';

// The stories' and tests' data: the plugin's JSON as AwsCostexplorerController answers it (the server's strings in
// Japanese).

const days = Array.from({ length: 30 }, (_, i) => {
  const date = `2026/${i < 6 ? '10' : '11'}/${String(i < 6 ? 26 + i : i - 5).padStart(2, '0')}`;
  return { date, value: 40 + ((i * 7) % 13), estimated: i >= 28 };
});

export const costs: CostexplorerJson = {
  enabled: true,
  failure: null,
  pending: null,
  updated: '2026/11/24 06:00',
  costs: {
    currency: 'USD',
    totals: { this_month: '1,234.57 USD', forecast: '1,702.10 USD', no_forecast: null, previous_month: '1,598.20 USD', previous_estimated: true },
    services: [
      {
        name: 'Amazon Relational Database Service',
        this_month: '512.40 USD',
        previous_month: '640.00 USD',
        details: [
          { name: 'APN1-InstanceUsage:db.t4g.medium', this_month: '480.00 USD', previous_month: '600.00 USD' },
          { name: 'APN1-RDS:GP3-Storage', this_month: '32.40 USD', previous_month: '40.00 USD' },
        ],
      },
      { name: 'AWS Lambda', this_month: '210.00 USD', previous_month: '260.10 USD', details: [] },
    ],
    daily: [...days].reverse().map((d) => ({ date: d.date, amount: `${d.value.toFixed(2)} USD`, estimated: d.estimated })),
    chart: {
      labels: days.map((d) => d.date),
      datasets: [
        { label: '非ブレンドコスト', data: days.map((d) => (d.estimated ? null : d.value)) },
        { label: '推定', data: days.map((d) => (d.estimated ? d.value : null)) },
      ],
    },
    tag: {
      key: 'project',
      label: 'コスト配分タグ別 (project)',
      no_data: false,
      rows: [
        { name: 'portal', this_month: '800.00 USD', previous_month: '900.00 USD' },
        { name: '(タグなし)', this_month: '434.57 USD', previous_month: '698.20 USD' },
      ],
    },
  },
};

// not on: no costs yet
export const disabled: CostexplorerJson = { enabled: false, failure: null, pending: null, updated: null, costs: null };

// the last fetch failed (the class only), unreachable, with the costs of the fetch before
export const failed: CostexplorerJson = {
  ...costs,
  failure: {
    text: '取得エラー: 2026/11/24 06:00 (Seahorse::Client::NetworkingError)',
    unreachable: 'Cost Explorer (ce.us-east-1.amazonaws.com) につながりませんでした。インターネットにつながらないネットワークでは、NAT などの経路が必要です。',
  },
};
