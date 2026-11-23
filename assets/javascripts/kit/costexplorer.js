// Redmine Kit AWS Cost Explorer: the plugin's module for the new UI, built from frontend/src by `npm run build` (frontend/vite.config.js).
// Edit the source, not this file. React, @redmine-kit/ui and @redmine-kit/plugin come from the app (the shell's import map).
import { Badge, BarChart, CardBody, CardSection, DataTable, DataTableSkeleton, EmptyState, KPI, KPIGrid, Notice, RequestErrorState, SkeletonRegion } from "@redmine-kit/ui";
import { CardHeaderActions, useKitQuery, useT } from "@redmine-kit/plugin";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";
// src/api.ts
var costPaths = { 
/** GET: the tab (the latest stored costs; the page never calls Cost Explorer) */
costs: "/admin/aws/costexplorer.json" };
// src/AwsCostexplorer.tsx
function useCostColumns(name, tree = false) {
	const t = useT();
	return [
		{
			key: "name",
			label: name,
			type: tree ? "tree" : "text",
			value: (r) => r.row.name
		},
		{
			key: "this",
			label: t("label_aws_costexplorer_this_month"),
			type: "text",
			align: "right",
			value: (r) => r.row.this_month
		},
		{
			key: "previous",
			label: t("label_aws_costexplorer_previous_month"),
			type: "text",
			align: "right",
			value: (r) => r.row.previous_month
		}
	];
}
function AwsCostexplorer() {
	const t = useT();
	const query = useKitQuery(costPaths.costs);
	if (query.isError) return /* @__PURE__ */ jsx(CardBody, { children: /* @__PURE__ */ jsx(RequestErrorState, {
		error: query.error,
		onRetry: () => void query.refetch(),
		retrying: query.isFetching
	}) });
	const data = query.data;
	if (!data) return /* @__PURE__ */ jsx(CostsSkeleton, {});
	const meta = data.pending ?? (data.updated ? t("label_aws_costexplorer_updated", { time: data.updated }) : null);
	return /* @__PURE__ */ jsxs(Fragment, { children: [meta && /* @__PURE__ */ jsx(CardHeaderActions, { children: /* @__PURE__ */ jsx("span", {
		className: "text-meta text-text-muted",
		children: meta
	}) }), /* @__PURE__ */ jsxs(CardBody, { children: [
		!data.enabled && /* @__PURE__ */ jsx(Notice, {
			tone: "warning",
			text: t("text_aws_costexplorer_disabled"),
			wrap: true
		}),
		data.failure && /* @__PURE__ */ jsx(Notice, {
			tone: "danger",
			text: [data.failure.text, data.failure.unreachable].filter(Boolean).join("\n"),
			wrap: true
		}),
		data.costs ? /* @__PURE__ */ jsx(Costs, { costs: data.costs }) : /* @__PURE__ */ jsx(EmptyState, { variant: "pane" })
	] })] });
}
function Costs({ costs }) {
	const t = useT();
	const serviceColumns = useCostColumns(t("label_aws_costexplorer_service"), true);
	const tagColumns = useCostColumns(costs.tag?.key ?? "");
	const estimated = /* @__PURE__ */ jsx(Badge, { children: t("label_aws_costexplorer_estimated") });
	const dayColumns = [{
		key: "date",
		label: t("label_date"),
		type: "text",
		value: (r) => r.day.date
	}, {
		key: "amount",
		label: t("label_aws_costexplorer_amount"),
		type: "text",
		align: "right",
		value: (r) => r.day.amount,
		cell: (r) => /* @__PURE__ */ jsxs("span", {
			className: "inline-flex items-center gap-2",
			children: [r.day.estimated && estimated, /* @__PURE__ */ jsx("span", {
				className: "tabular-nums",
				children: r.day.amount
			})]
		})
	}];
	const services = costs.services.flatMap((service, i) => [{
		id: `s${i}`,
		row: service,
		...service.details.length > 0 && { caret: "closed" }
	}, ...service.details.map((detail, j) => ({
		id: `s${i}-${j}`,
		row: detail,
		level: 1
	}))]);
	const chart = costs.chart;
	return /* @__PURE__ */ jsxs(Fragment, { children: [
		/* @__PURE__ */ jsx(CardSection, {
			line: false,
			heading: t("label_total"),
			children: /* @__PURE__ */ jsx("div", {
				className: "px-gutter",
				children: /* @__PURE__ */ jsxs(KPIGrid, {
					columns: 3,
					children: [
						/* @__PURE__ */ jsx(KPI, {
							label: t("label_aws_costexplorer_this_month"),
							value: costs.totals.this_month
						}),
						/* @__PURE__ */ jsx(KPI, {
							label: t("label_aws_costexplorer_forecast"),
							value: costs.totals.forecast ?? "-",
							note: costs.totals.no_forecast ?? void 0
						}),
						/* @__PURE__ */ jsx(KPI, {
							label: t("label_aws_costexplorer_previous_month"),
							value: costs.totals.previous_month,
							verdict: costs.totals.previous_estimated ? {
								label: t("label_aws_costexplorer_estimated"),
								tone: "neutral"
							} : void 0
						})
					]
				})
			})
		}),
		/* @__PURE__ */ jsx(CardSection, {
			heading: t("label_aws_costexplorer_by_service"),
			children: services.length === 0 ? /* @__PURE__ */ jsx(EmptyState, {}) : /* @__PURE__ */ jsx(DataTable, {
				label: t("label_aws_costexplorer_by_service"),
				columns: serviceColumns,
				rows: services
			})
		}),
		/* @__PURE__ */ jsx(CardSection, {
			heading: t("label_aws_costexplorer_daily"),
			children: costs.daily.length === 0 || !chart ? /* @__PURE__ */ jsx(EmptyState, {}) : /* @__PURE__ */ jsxs("div", {
				className: "flex flex-col gap-4",
				children: [/* @__PURE__ */ jsx("div", {
					className: "px-gutter",
					children: /* @__PURE__ */ jsx(BarChart, {
						orientation: "vertical",
						label: t("label_aws_costexplorer_daily_chart"),
						unit: ` ${costs.currency}`,
						series: chart.datasets.map((dataset, i) => ({
							key: `d${i}`,
							label: dataset.label,
							tone: i === 0 ? "done" : "carry"
						})),
						rows: chart.labels.map((label, day) => ({
							label,
							...Object.fromEntries(chart.datasets.map((dataset, i) => [`d${i}`, dataset.data[day] ?? 0]))
						})),
						hasTotal: false
					})
				}), /* @__PURE__ */ jsx(DataTable, {
					label: t("label_aws_costexplorer_daily"),
					columns: dayColumns,
					rows: costs.daily.map((day) => ({
						id: day.date,
						day
					}))
				})]
			})
		}),
		costs.tag && /* @__PURE__ */ jsxs(CardSection, {
			heading: costs.tag.label,
			children: [costs.tag.no_data && /* @__PURE__ */ jsx(Notice, {
				tone: "warning",
				text: t("text_aws_costexplorer_no_tag_data", { tag: costs.tag.key }),
				wrap: true
			}), costs.tag.rows.length > 0 && /* @__PURE__ */ jsx(DataTable, {
				label: costs.tag.label,
				columns: tagColumns,
				rows: costs.tag.rows.map((row, i) => ({
					id: `t${i}`,
					row
				}))
			})]
		})
	] });
}
/** The tab while its JSON loads: the totals' three numbers and the services' table. */
function CostsSkeleton() {
	const t = useT();
	const columns = useCostColumns(t("label_aws_costexplorer_service"), true);
	return /* @__PURE__ */ jsx(CardBody, { children: /* @__PURE__ */ jsxs(SkeletonRegion, {
		label: t("label_loading"),
		children: [/* @__PURE__ */ jsx(CardSection, {
			line: false,
			heading: t("label_total"),
			children: /* @__PURE__ */ jsx("div", {
				className: "px-gutter",
				children: /* @__PURE__ */ jsx(KPIGrid, {
					columns: 3,
					children: [
						"label_aws_costexplorer_this_month",
						"label_aws_costexplorer_forecast",
						"label_aws_costexplorer_previous_month"
					].map((key) => /* @__PURE__ */ jsx(KPI, {
						label: t(key),
						value: "​"
					}, key))
				})
			})
		}), /* @__PURE__ */ jsx(CardSection, {
			heading: t("label_aws_costexplorer_by_service"),
			children: /* @__PURE__ */ jsx(DataTableSkeleton, {
				label: t("label_aws_costexplorer_by_service"),
				loading: t("label_loading"),
				columns,
				rows: 5
			})
		})]
	}) });
}
export { AwsCostexplorer };
