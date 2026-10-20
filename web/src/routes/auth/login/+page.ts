import { getPublicConfig } from '@immich/sdk';
import { redirect } from '@sveltejs/kit';
import { authManager } from '$lib/managers/auth-manager.svelte';
import { serverConfigManager } from '$lib/managers/server-config-manager.svelte';
import { Route } from '$lib/route';
import { getFormatter } from '$lib/utils/i18n';
import type { PageLoad } from './$types';

export const load = (async ({ parent, url }) => {
  await parent();

  const continueUrl = Route.continue(url.searchParams.get('continue'), Route.photos());
  const isOAuthCallback = url.searchParams.has('code') || url.searchParams.has('error');
  const isOAuthAutoLaunch = url.searchParams.has('autoLaunch');
  if (authManager.authenticated && !isOAuthCallback && !isOAuthAutoLaunch) {
    redirect(307, continueUrl);
  }

  if (!serverConfigManager.value.isInitialized) {
    // Admin not registered
    redirect(307, Route.register());
  }

  const publicConfig = await getPublicConfig();

  const $t = await getFormatter();
  return {
    meta: {
      title: $t('login'),
    },
    continueUrl,
    publicConfig,
  };
}) satisfies PageLoad;
