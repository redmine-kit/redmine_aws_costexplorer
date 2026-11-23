import {
  Badge,
  BarChart,
  CardBody,
  CardSection,
  DataTable,
  DataTableSkeleton,
  EmptyState,
  KPI,
  KPIGrid,
  Notice,
  RequestErrorState,
  SkeletonRegion,
  type DataTableColumn,
  type DataTableRowBase,
} from '@redmine-kit/ui';
import { CardHeaderActions, useKitQuery, useT } from '@redmine-kit/plugin';
import { costPaths, type CostRow, type CostexplorerJson, type CostsJson } from './api';

// Administration › AWS › Cost Explorer (/admin/aws/costexplorer: the manifest's layout: admin screen with menu_item aws,
// its tab label_aws_costexplorer at position 60), as Redmine's page shows it (app/views/aws_costexplorer/index.html.erb),
// from the latest costs the daily fetch stored (the page never calls Cost Explorer):
// - without REDMINE_COSTEXPLORER_ENABLED, the warning that no costs are fetched; the last fetch's failure (the class of
//   its error, and the network's advice when Cost Explorer couldn't be reached);
// - the card's header: when the costs were read (1 日 1 回), or that a fetch is running;
// - 合計: this month, the forecast (or why there is none) and last month (推定 while Cost Explorer hasn't finalized it);
// - サービス別: each service with its usage types folded under it, as the page's grouped rows;
// - 日別 (直近 30 日間): the chart (the final costs and the estimated ones stacked) and the table under it, newest first;
// - コスト配分タグ別, when a tag is set, with the warning while no cost carries it yet.
// Every amount comes formatted by the server (Redmine's helpers); nothing here is an action.

interface ServiceRow extends DataTableRowBase {
  row: CostRow;
}

interface DayRow extends DataTableRowBase {
  day: CostsJson['daily'][number];
}

function useCostColumns(name: string, tree = false): DataTableColumn<ServiceRow>[] {
  const t = useT();
  return [
    { key: 'name', label: name, type: tree ? 'tree' : 'text', value: (r) => r.row.name },
    { key: 'this', label: t('label_aws_costexplorer_this_month'), type: 'text', align: 'right', value: (r) => r.row.this_month },
    { key: 'previous', label: t('label_aws_costexplorer_previous_month'), type: 'text', align: 'right', value: (r) => r.row.previous_month },
  ];
}

export function AwsCostexplorer() {
  const t = useT();
  const query = useKitQuery<CostexplorerJson>(costPaths.costs);
  if (query.isError)
    return (
      <CardBody>
        <RequestErrorState error={query.error} onRetry={() => void query.refetch()} retrying={query.isFetching} />
      </CardBody>
    );
  const data = query.data;
  if (!data) return <CostsSkeleton />;
  const meta = data.pending ?? (data.updated ? t('label_aws_costexplorer_updated', { time: data.updated }) : null);
  return (
    <>
      {meta && (
        <CardHeaderActions>
          <span className="text-meta text-text-muted">{meta}</span>
        </CardHeaderActions>
      )}
      <CardBody>
        {!data.enabled && <Notice tone="warning" text={t('text_aws_costexplorer_disabled')} wrap />}
        {data.failure && <Notice tone="danger" text={[data.failure.text, data.failure.unreachable].filter(Boolean).join('\n')} wrap />}
        {data.costs ? <Costs costs={data.costs} /> : <EmptyState variant="pane" />}
      </CardBody>
    </>
  );
}

function Costs({ costs }: { costs: CostsJson }) {
  const t = useT();
  const serviceColumns = useCostColumns(t('label_aws_costexplorer_service'), true);
  const tagColumns = useCostColumns(costs.tag?.key ?? '');
  const estimated = <Badge>{t('label_aws_costexplorer_estimated')}</Badge>;
  const dayColumns: DataTableColumn<DayRow>[] = [
    { key: 'date', label: t('label_date'), type: 'text', value: (r) => r.day.date },
    {
      key: 'amount',
      label: t('label_aws_costexplorer_amount'),
      type: 'text',
      align: 'right',
      value: (r) => r.day.amount,
      // the badge before the amount, so that the amounts stay aligned on the right (as the page)
      cell: (r) => (
        <span className="inline-flex items-center gap-2">
          {r.day.estimated && estimated}
          <span className="tabular-nums">{r.day.amount}</span>
        </span>
      ),
    },
  ];
  const services: ServiceRow[] = costs.services.flatMap((service, i) => [
    { id: `s${i}`, row: service, ...(service.details.length > 0 && { caret: 'closed' as const }) },
    ...service.details.map((detail, j) => ({ id: `s${i}-${j}`, row: detail, level: 1 })),
  ]);
  const chart = costs.chart;
  return (
    <>
      <CardSection line={false} heading={t('label_total')}>
        <div className="px-gutter">
          <KPIGrid columns={3}>
            <KPI label={t('label_aws_costexplorer_this_month')} value={costs.totals.this_month} />
            <KPI label={t('label_aws_costexplorer_forecast')} value={costs.totals.forecast ?? '-'} note={costs.totals.no_forecast ?? undefined} />
            <KPI
              label={t('label_aws_costexplorer_previous_month')}
              value={costs.totals.previous_month}
              verdict={costs.totals.previous_estimated ? { label: t('label_aws_costexplorer_estimated'), tone: 'neutral' } : undefined}
            />
          </KPIGrid>
        </div>
      </CardSection>
      <CardSection heading={t('label_aws_costexplorer_by_service')}>
        {services.length === 0 ? (
          <EmptyState />
        ) : (
          <DataTable<ServiceRow> label={t('label_aws_costexplorer_by_service')} columns={serviceColumns} rows={services} />
        )}
      </CardSection>
      <CardSection heading={t('label_aws_costexplorer_daily')}>
        {costs.daily.length === 0 || !chart ? (
          <EmptyState />
        ) : (
          <div className="flex flex-col gap-4">
            <div className="px-gutter">
              <BarChart
                orientation="vertical"
                label={t('label_aws_costexplorer_daily_chart')}
                unit={` ${costs.currency}`}
                series={chart.datasets.map((dataset, i) => ({ key: `d${i}`, label: dataset.label, tone: i === 0 ? 'done' : 'carry' }))}
                rows={chart.labels.map((label, day) => ({ label, ...Object.fromEntries(chart.datasets.map((dataset, i) => [`d${i}`, dataset.data[day] ?? 0])) }))}
                hasTotal={false}
              />
            </div>
            <DataTable<DayRow> label={t('label_aws_costexplorer_daily')} columns={dayColumns} rows={costs.daily.map((day) => ({ id: day.date, day }))} />
          </div>
        )}
      </CardSection>
      {costs.tag && (
        <CardSection heading={costs.tag.label}>
          {costs.tag.no_data && <Notice tone="warning" text={t('text_aws_costexplorer_no_tag_data', { tag: costs.tag.key })} wrap />}
          {costs.tag.rows.length > 0 && (
            <DataTable<ServiceRow> label={costs.tag.label} columns={tagColumns} rows={costs.tag.rows.map((row, i) => ({ id: `t${i}`, row }))} />
          )}
        </CardSection>
      )}
    </>
  );
}

/** The tab while its JSON loads: the totals' three numbers and the services' table. */
function CostsSkeleton() {
  const t = useT();
  const columns = useCostColumns(t('label_aws_costexplorer_service'), true);
  return (
    <CardBody>
      <SkeletonRegion label={t('label_loading')}>
        <CardSection line={false} heading={t('label_total')}>
          <div className="px-gutter">
            <KPIGrid columns={3}>
              {['label_aws_costexplorer_this_month', 'label_aws_costexplorer_forecast', 'label_aws_costexplorer_previous_month'].map((key) => (
                // the label, and the number's line kept empty (KPI draws text only) so that the row keeps its height
                <KPI key={key} label={t(key)} value={'\u200b'} />
              ))}
            </KPIGrid>
          </div>
        </CardSection>
        <CardSection heading={t('label_aws_costexplorer_by_service')}>
          <DataTableSkeleton<ServiceRow> label={t('label_aws_costexplorer_by_service')} loading={t('label_loading')} columns={columns} rows={5} />
        </CardSection>
      </SkeletonRegion>
    </CardBody>
  );
}
