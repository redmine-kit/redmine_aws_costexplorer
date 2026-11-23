import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ApiError } from '@redmine-kit/plugin';
import { CardHeaderActionsContext } from '@redmine-kit/plugin/host';
import { describe, expect, it } from 'vitest';
import { AwsCostexplorer } from './AwsCostexplorer';
import { costs, disabled, failed } from './fixtures';
import { renderKit } from './test/render';

// The Cost Explorer tab on the plugin's JSON as AwsCostexplorerController answers it.
const COSTS = 'GET /admin/aws/costexplorer.json';

describe('AwsCostexplorer', () => {
  it('shows the totals, last month estimated, the services, the days and the tag', async () => {
    renderKit(<AwsCostexplorer />, { responses: { [COSTS]: costs } });
    expect(await screen.findByText('1,234.57 USD')).toBeInTheDocument();
    expect(screen.getByText('1,702.10 USD')).toBeInTheDocument();
    expect(screen.getAllByText('推定').length).toBeGreaterThan(0);
    const services = screen.getByRole('table', { name: 'サービス別' });
    expect(within(services).getByText('Amazon Relational Database Service')).toBeInTheDocument();
    expect(within(screen.getByRole('table', { name: '日別 (直近 30 日間)' })).getAllByRole('row')).toHaveLength(31);
    expect(within(screen.getByRole('table', { name: 'コスト配分タグ別 (project)' })).getByText('(タグなし)')).toBeInTheDocument();
  });

  it("folds a service's usage types under it, as the page's grouped rows", async () => {
    const user = userEvent.setup();
    renderKit(<AwsCostexplorer />, { responses: { [COSTS]: costs } });
    await screen.findByText('1,234.57 USD');
    const services = screen.getByRole('table', { name: 'サービス別' });
    expect(within(services).queryByText('APN1-RDS:GP3-Storage')).toBeNull();
    await user.click(within(services).getAllByRole('button')[0]);
    expect(within(services).getByText('APN1-RDS:GP3-Storage')).toBeInTheDocument();
  });

  it('not on: the warning and 表示するデータがありません; a failed fetch: its class and the advice', async () => {
    const { unmount } = renderKit(<AwsCostexplorer />, { responses: { [COSTS]: disabled } });
    expect(await screen.findByText('REDMINE_COSTEXPLORER_ENABLED が true でないため、コストを取得しません。')).toBeInTheDocument();
    expect(screen.getByText('表示するデータがありません')).toBeInTheDocument();
    unmount();
    renderKit(<AwsCostexplorer />, { responses: { [COSTS]: failed } });
    expect(await screen.findByText(/Seahorse::Client::NetworkingError/)).toBeInTheDocument();
    expect(screen.getByText(/NAT などの経路が必要です/)).toBeInTheDocument();
  });

  it("says when the costs were read in the card's header, or that a fetch is running", async () => {
    const header = document.body.appendChild(document.createElement('div'));
    const { unmount } = renderKit(
      <CardHeaderActionsContext value={header}>
        <AwsCostexplorer />
      </CardHeaderActionsContext>,
      { responses: { [COSTS]: costs } },
    );
    expect(await within(header).findByText('更新: 2026/11/24 06:00 (1 日 1 回)')).toBeInTheDocument();
    unmount();
    renderKit(
      <CardHeaderActionsContext value={header}>
        <AwsCostexplorer />
      </CardHeaderActionsContext>,
      { responses: { [COSTS]: { ...costs, pending: '更新: 実行中 (2026/11/24 06:00 から)' } } },
    );
    expect(await within(header).findByText('更新: 実行中 (2026/11/24 06:00 から)')).toBeInTheDocument();
    header.remove();
  });

  it('is a skeleton while it loads, and the error state when it cannot be read', async () => {
    const { unmount } = renderKit(<AwsCostexplorer />, { responses: { [COSTS]: new Promise(() => {}) } });
    expect(screen.getAllByRole('status', { name: 'ロード中...' }).length).toBeGreaterThan(0);
    unmount();
    renderKit(<AwsCostexplorer />, { responses: { [COSTS]: new ApiError(500, []) } });
    expect(await screen.findByRole('button', { name: /再読み込み|再試行/ })).toBeInTheDocument();
  });
});
