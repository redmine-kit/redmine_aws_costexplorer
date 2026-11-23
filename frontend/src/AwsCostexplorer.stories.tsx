import { kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { AwsCostexplorer } from './AwsCostexplorer';
import { costs, disabled, failed } from './fixtures';

// Administration › AWS › Cost Explorer (the manifest's /admin/aws/costexplorer, a tab of the page AWS), in the app's card
// with the page's title.
const meta = {
  title: 'Screens/AwsCostexplorer',
  component: AwsCostexplorer,
  ...kitStory({ frame: 'card', bare: true, title: 'AWS', responses: { 'GET /admin/aws/costexplorer.json': costs } }),
} satisfies Meta<typeof AwsCostexplorer>;

export default meta;
type Story = StoryObj<typeof meta>;

/** The totals, the services, 30 days and a tag. */
export const Default: Story = {};

/** Not on, no costs. */
export const Disabled: Story = kitStory({ responses: { 'GET /admin/aws/costexplorer.json': disabled } });

/** The last fetch failed: Cost Explorer couldn't be reached. */
export const FetchFailed: Story = kitStory({ responses: { 'GET /admin/aws/costexplorer.json': failed } });

export const Loading: Story = kitStory({ state: 'loading' });
export const Failed: Story = kitStory({ state: 'error' });
export const Forbidden: Story = kitStory({ state: 'forbidden' });
