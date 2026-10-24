<script lang="ts">
  import { createPreloadedQuery } from '$lib/queries/client';
  import { getAdminConfigQuery } from '$lib/queries/config-admin.query';
  import { cloneDeep } from 'lodash-es';
  import SettingAccordion from '$lib/components/shared-components/settings/SettingAccordion.svelte';
  import SettingInputField from '$lib/components/shared-components/settings/SettingInputField.svelte';
  import SettingSelect from './SettingSelect.svelte';
  import SettingSwitch from '$lib/components/shared-components/settings/SettingSwitch.svelte';
  import SettingButtonsRow from '$lib/components/shared-components/settings/SystemConfigButtonRow.svelte';
  import { SettingInputFieldType } from '$lib/constants';
  import FormatMessage from '$lib/elements/FormatMessage.svelte';
  import { featureFlagsManager } from '$lib/managers/feature-flags-manager.svelte';
  import { handleError } from '$lib/utils/handle-error';
  import { ChecksumAlgorithm, ChecksumRehashTarget, recomputeChecksums } from '@immich/sdk';
  import { Button, Link, modalManager, toastManager } from '@immich/ui';
  import { mdiDatabaseRefreshOutline } from '@mdi/js';
  import { t } from 'svelte-i18n';
  import { fade } from 'svelte/transition';

  const query = createPreloadedQuery(getAdminConfigQuery);
  const config = $derived(query.data);

  const disabled = $derived(featureFlagsManager.value.configFile);
  let configToEdit = $state(cloneDeep(config));

  let cronExpressionOptions = $derived([
    { text: $t('interval.night_at_midnight'), value: '0 0 * * *' },
    { text: $t('interval.night_at_twoam'), value: '0 2 * * *' },
    { text: $t('interval.day_at_onepm'), value: '0 13 * * *' },
    { text: $t('interval.hours', { values: { hours: 6 } }), value: '0 */6 * * *' },
  ]);

  const checksumOptions = $derived([
    { value: ChecksumAlgorithm.Sha1, text: $t('admin.checksum_content_sha1') },
    { value: ChecksumAlgorithm.Sha1Path, text: $t('admin.checksum_path_sha1') },
  ]);

  const checksumSettingsChanged = $derived(
    configToEdit.library.checksum.external !== config.library.checksum.external ||
      configToEdit.library.checksum.dedupeUploadsAgainstLibraries !==
        config.library.checksum.dedupeUploadsAgainstLibraries,
  );

  const handleRecompute = async (target: ChecksumRehashTarget) => {
    const confirmed = await modalManager.showDialog({
      icon: mdiDatabaseRefreshOutline,
      title: $t('admin.recompute_checksums'),
      prompt:
        target === ChecksumRehashTarget.External
          ? $t('admin.recompute_external_checksums_prompt')
          : $t('admin.recompute_upload_checksums_prompt'),
      confirmText: $t('admin.recompute_checksums'),
      confirmColor: 'primary',
    });

    if (!confirmed) {
      return;
    }

    try {
      await recomputeChecksums({ recomputeChecksumsDto: { target } });
      toastManager.info($t('admin.recompute_checksums_queued'));
    } catch (error) {
      handleError(error, $t('errors.something_went_wrong'));
    }
  };
</script>

<div>
  <div in:fade={{ duration: 500 }}>
    <form autocomplete="off" onsubmit={(event) => event.preventDefault()}>
      <div class="ms-4 mt-4 flex flex-col gap-4">
        <SettingAccordion
          key="library-checksums"
          title={$t('admin.library_checksum_settings')}
          subtitle={$t('admin.library_checksum_settings_description')}
        >
          <div class="ms-4 mt-4 flex flex-col gap-4">
            <SettingSelect
              name="external-checksum"
              label={$t('admin.library_external_checksum')}
              desc={$t('admin.library_external_checksum_description')}
              options={checksumOptions}
              bind:value={configToEdit.library.checksum.external}
              {disabled}
              isEdited={configToEdit.library.checksum.external !== config.library.checksum.external}
            />

            <SettingSelect
              name="upload-checksum"
              label={$t('admin.library_upload_checksum')}
              desc={$t('admin.library_upload_checksum_description')}
              options={[{ value: ChecksumAlgorithm.Sha1, text: $t('admin.checksum_content_sha1') }]}
              value={ChecksumAlgorithm.Sha1}
              disabled={true}
            />

            <SettingSwitch
              title={$t('admin.library_dedupe_uploads')}
              subtitle={$t('admin.library_dedupe_uploads_description')}
              bind:checked={configToEdit.library.checksum.dedupeUploadsAgainstLibraries}
              {disabled}
              isEdited={configToEdit.library.checksum.dedupeUploadsAgainstLibraries !==
                config.library.checksum.dedupeUploadsAgainstLibraries}
            />

            <div class="flex flex-wrap gap-2">
              <Button
                size="small"
                variant="ghost"
                shape="round"
                disabled={disabled || checksumSettingsChanged}
                onclick={() => handleRecompute(ChecksumRehashTarget.External)}
              >
                {$t('admin.recompute_external_checksums')}
              </Button>
              <Button
                size="small"
                variant="ghost"
                shape="round"
                disabled={disabled || checksumSettingsChanged}
                onclick={() => handleRecompute(ChecksumRehashTarget.Upload)}
              >
                {$t('admin.recompute_upload_checksums')}
              </Button>
            </div>

            {#if checksumSettingsChanged}
              <p class="text-sm text-orange-600 dark:text-orange-400">
                {$t('admin.recompute_checksums_unsaved')}
              </p>
            {/if}

            <p class="text-sm dark:text-immich-dark-fg">{$t('admin.recompute_checksums_description')}</p>
          </div>
        </SettingAccordion>

        <SettingAccordion
          key="library-watching"
          title={$t('admin.library_watching_settings')}
          subtitle={$t('admin.library_watching_settings_description')}
        >
          <div class="ms-4 mt-4 flex flex-col gap-4">
            <SettingSwitch
              title={$t('admin.library_watching_enable_description')}
              {disabled}
              bind:checked={configToEdit.library.watch.enabled}
            />
          </div>
        </SettingAccordion>

        <SettingAccordion
          key="library-scanning"
          title={$t('admin.library_scanning')}
          subtitle={$t('admin.library_scanning_description')}
        >
          <div class="ms-4 mt-4 flex flex-col gap-4">
            <SettingSwitch
              title={$t('admin.library_scanning_enable_description')}
              {disabled}
              bind:checked={configToEdit.library.scan.enabled}
            />

            <SettingSelect
              options={cronExpressionOptions}
              disabled={disabled || !configToEdit.library.scan.enabled}
              name="expression"
              label={$t('admin.cron_expression_presets')}
              bind:value={configToEdit.library.scan.cronExpression}
            />

            <SettingInputField
              inputType={SettingInputFieldType.TEXT}
              required={true}
              disabled={disabled || !configToEdit.library.scan.enabled}
              label={$t('admin.cron_expression')}
              bind:value={configToEdit.library.scan.cronExpression}
              isEdited={configToEdit.library.scan.cronExpression !== config.library.scan.cronExpression}
            >
              {#snippet descriptionSnippet()}
                <p class="text-sm dark:text-immich-dark-fg">
                  <FormatMessage key="admin.cron_expression_description">
                    {#snippet children({ message })}
                      <Link
                        href="https://crontab.guru/#{configToEdit.library.scan.cronExpression.replaceAll(' ', '_')}"
                      >
                        {message}
                      </Link>
                    {/snippet}
                  </FormatMessage>
                </p>
              {/snippet}
            </SettingInputField>
          </div>
        </SettingAccordion>

        <SettingButtonsRow bind:configToEdit keys={['library']} {disabled} />
      </div>
    </form>
  </div>
</div>
