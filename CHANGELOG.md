# Changelog

## [0.4.0](https://github.com/nlamirault/agentheon/compare/v0.3.0...v0.4.0) (2026-09-04)


### 🚀 Features

* **agents:** add Daedalus for developer experience and tooling ([#48](https://github.com/nlamirault/agentheon/issues/48)) ([82040da](https://github.com/nlamirault/agentheon/commit/82040da8165b543f2bd204e664e12290332a3d3d))
* **agents:** add executive tier, C-suite skills, and profile tooling ([#51](https://github.com/nlamirault/agentheon/issues/51)) ([bcb55d1](https://github.com/nlamirault/agentheon/commit/bcb55d16e1028fcd6c6012b0362359f694c92edc))
* **agents:** add model default and base_url to profile config ([#54](https://github.com/nlamirault/agentheon/issues/54)) ([fc2a464](https://github.com/nlamirault/agentheon/commit/fc2a464b98b2a8899fad15f4cb9cfa6d847120fb))
* **agents:** add persona, confidence routing, and quality gates ([#41](https://github.com/nlamirault/agentheon/issues/41)) ([fca16ba](https://github.com/nlamirault/agentheon/commit/fca16baf948305a01b3cf0c76db4a70178be185f))
* **agents:** default profiles to openrouter/meta/muse-spark-1.3 ([#53](https://github.com/nlamirault/agentheon/issues/53)) ([fb858a3](https://github.com/nlamirault/agentheon/commit/fb858a3edd1c127f238f2a402c0a49a314802d97))
* **agents:** split SOUL.md into identity and AGENTS.md project guide ([#45](https://github.com/nlamirault/agentheon/issues/45)) ([9657b96](https://github.com/nlamirault/agentheon/commit/9657b96f727d47554c44db8a771d8181f463ac23))
* **avatars:** logo-style deity avatars, generated and used across the site ([#44](https://github.com/nlamirault/agentheon/issues/44)) ([a987e0d](https://github.com/nlamirault/agentheon/commit/a987e0da609977e1f04e240fc49d93372004360c))
* **crons:** add five high-value OSS maintenance crons ([#39](https://github.com/nlamirault/agentheon/issues/39)) ([b65bbad](https://github.com/nlamirault/agentheon/commit/b65bbad1964dbd38b7cd1296f30326caaf441f70))
* **crons:** weekly digest cron subsystem (Iris) ([#37](https://github.com/nlamirault/agentheon/issues/37)) ([316c1de](https://github.com/nlamirault/agentheon/commit/316c1de6fb79f870b2fb094de847934e9ea96cd8)), closes [#36](https://github.com/nlamirault/agentheon/issues/36)
* **profiles:** resolve model column from installed config.yaml ([#55](https://github.com/nlamirault/agentheon/issues/55)) ([87ff50b](https://github.com/nlamirault/agentheon/commit/87ff50b37a063f1a97e0e340c73998ce320dcfed))
* **script:** use distinct emoji for skill and cron installs ([#40](https://github.com/nlamirault/agentheon/issues/40)) ([0f33fa4](https://github.com/nlamirault/agentheon/commit/0f33fa4583b8a7c55c81574880d66a67d57a4059))
* **secrets:** require a secret source via new CLI flags ([#49](https://github.com/nlamirault/agentheon/issues/49)) ([82f079a](https://github.com/nlamirault/agentheon/commit/82f079a07998ccaef4fe0c7e0a45e46104ed48c1))
* **secrets:** wire Bitwarden secret source into profile generator ([#47](https://github.com/nlamirault/agentheon/issues/47)) ([c4d0a92](https://github.com/nlamirault/agentheon/commit/c4d0a923c321e6b825e350534e32316950cf6beb))
* **web:** display Agentheon version in footer ([#26](https://github.com/nlamirault/agentheon/issues/26)) ([0cabab2](https://github.com/nlamirault/agentheon/commit/0cabab29a88cfb30038245e66cf007b32b64bf6d))
* **web:** render docs content on the website ([#30](https://github.com/nlamirault/agentheon/issues/30)) ([d11c77d](https://github.com/nlamirault/agentheon/commit/d11c77d563484a93abb19bed457ef21fb69a8293))


### 🐛 Bug Fixes

* **agents:** prune orphan skill references from executive READMEs ([#52](https://github.com/nlamirault/agentheon/issues/52)) ([3fcf6da](https://github.com/nlamirault/agentheon/commit/3fcf6da9b262083a44be8866c915234252abfe53))
* **generator:** default profiles to nous-portal free model ([#29](https://github.com/nlamirault/agentheon/issues/29)) ([dd5f75b](https://github.com/nlamirault/agentheon/commit/dd5f75b9339a268bfc44362f76148e9cd2f6eb95))
* **zeus:** enforce delegation-only by dropping hermes-cli toolset ([#50](https://github.com/nlamirault/agentheon/issues/50)) ([d83064f](https://github.com/nlamirault/agentheon/commit/d83064f1995fa6e63510ecb21c06d4c63012e361))


### 🚨 Maintenance

* **hack:** default profile models to tencent/hy3:free ([#28](https://github.com/nlamirault/agentheon/issues/28)) ([fa366aa](https://github.com/nlamirault/agentheon/commit/fa366aac1b6b9a6d2565cd61db8c8c60162453a8))

## [0.3.0](https://github.com/nlamirault/agentheon/compare/v0.2.0...v0.3.0) (2026-08-31)


### 🚀 Features

* **agents:** add four deities and profile validation tooling ([#24](https://github.com/nlamirault/agentheon/issues/24)) ([a2aef6b](https://github.com/nlamirault/agentheon/commit/a2aef6bd5211983cbae943c35edc46089c91f5dd))
* **agents:** vendor missing skills for atlas, nemesis, plutus, poseidon ([#25](https://github.com/nlamirault/agentheon/issues/25)) ([8cdc23a](https://github.com/nlamirault/agentheon/commit/8cdc23a3b59b9a7352d18eb51e069e4d25d4a128))
* **web:** merge caduceus and pantheon into the brand logo ([#23](https://github.com/nlamirault/agentheon/issues/23)) ([4f83708](https://github.com/nlamirault/agentheon/commit/4f83708e0f5a858d5fb089984001a644746d5372))


### 🐛 Bug Fixes

* **agents:** vendor skills declared in frontmatter but missing on disk ([#22](https://github.com/nlamirault/agentheon/issues/22)) ([5043a25](https://github.com/nlamirault/agentheon/commit/5043a254793581dab7c8b71feb664c2a6c8e5e8d))
* **install:** install vendored skills into per-profile store ([#20](https://github.com/nlamirault/agentheon/issues/20)) ([e158e87](https://github.com/nlamirault/agentheon/commit/e158e87c1a221a83e7819897d543cc4475879216))

## [0.2.0](https://github.com/nlamirault/agentheon/compare/v0.1.0...v0.2.0) (2026-08-30)


### 🚀 Features

* **agents:** add profile aliases and rename orchestrator to Zeus ([#14](https://github.com/nlamirault/agentheon/issues/14)) ([1da8c4e](https://github.com/nlamirault/agentheon/commit/1da8c4e44f079bc806032e7414dd4cebaaeaf2ff))
* **agents:** restructure into per-agent dirs with vendored skills ([#17](https://github.com/nlamirault/agentheon/issues/17)) ([113908f](https://github.com/nlamirault/agentheon/commit/113908f9f0f459d1988e369d90cac50f4b176a71))
* **web:** add pantheon temple icon to homepage ([#19](https://github.com/nlamirault/agentheon/issues/19)) ([43f03c2](https://github.com/nlamirault/agentheon/commit/43f03c2143bfd1b5ee5cb4e1348c18e20ea8de3d))
* **web:** deploy website to Cloudflare Workers ([#12](https://github.com/nlamirault/agentheon/issues/12)) ([299f83d](https://github.com/nlamirault/agentheon/commit/299f83d0d7cb955dd9e87aceee52cb450dfcb5d8))


### 📚 Documentation

* **web:** document Workers Builds root directory setting ([#18](https://github.com/nlamirault/agentheon/issues/18)) ([a89f281](https://github.com/nlamirault/agentheon/commit/a89f281187eafe8e28229b908f6b9cd2563c3d08))

## 0.1.0 (2026-08-28)

### 🚀 Features

* **agents:** add five software-engineering deities ([#4](https://github.com/nlamirault/agentheon/issues/4))
  ([7830630](https://github.com/nlamirault/agentheon/commit/78306301d294226e912b2096dda5662139ecc5e3))
* **agents:** add Hermes profiles, coordination layer, new deities ([#5](https://github.com/nlamirault/agentheon/issues/5))
  ([eb59453](https://github.com/nlamirault/agentheon/commit/eb5945344a46d2780a74075042de9c84ece7e8ef))
* **brand:** add caduceus logo, design system, and website assets ([#11](https://github.com/nlamirault/agentheon/issues/11))
  ([c19e58f](https://github.com/nlamirault/agentheon/commit/c19e58f73ecd20146ac7669b6df4335e6cc48849))
* **install:** add agentheon.sh VPS installer for Hermes profiles ([#8](https://github.com/nlamirault/agentheon/issues/8))
  ([7a345f3](https://github.com/nlamirault/agentheon/commit/7a345f3f9026a32f9d6202fa975c4f628833a5f9))
* **web:** add agent profiles and Astro showcase site ([#2](https://github.com/nlamirault/agentheon/issues/2))
  ([5947d90](https://github.com/nlamirault/agentheon/commit/5947d908ce8170b47dbd59abca06652116deb40d))

### 🚨 Maintenance

* bootstrap project with essential configuration and automation ([1be938b](https://github.com/nlamirault/agentheon/commit/1be938ba0468198aaf9da39c06a536faf4532944))
* bootstrap project with essential configuration and automation ([8ecbe15](https://github.com/nlamirault/agentheon/commit/8ecbe150cb68bacf1916959d36d511662d8cd3c3))
* **deps:** Bump astro from 5.18.2 to 7.1.1 in /web ([#3](https://github.com/nlamirault/agentheon/issues/3))
  ([7bcbfff](https://github.com/nlamirault/agentheon/commit/7bcbfff21726a1828a48b63b986255f10f6740c0))

### 📚 Documentation

* add Diátaxis documentation structure ([#6](https://github.com/nlamirault/agentheon/issues/6)) ([5df0a4f](https://github.com/nlamirault/agentheon/commit/5df0a4f132ff6b5499a217c4812936e3c9eaff01))
* **adr:** add ADR-0001 for Hermes as sole orchestrator ([#10](https://github.com/nlamirault/agentheon/issues/10))
  ([a018e59](https://github.com/nlamirault/agentheon/commit/a018e5947c07a218e3cf9eba2d975dcf0604f16b))
* **how-to:** add guide for installing the pantheon with agentheon.sh ([#9](https://github.com/nlamirault/agentheon/issues/9))
  ([696f069](https://github.com/nlamirault/agentheon/commit/696f0695ea256778acf119e92389d6122bf3a038))
