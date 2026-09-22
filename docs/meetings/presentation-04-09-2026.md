# AI Practitioners Lab — LLM-Wiki Starter Kit

## Introduction

Thanks for the opportunity to talk about LLM-Wikis and their use in AI ASD.

In the last months, since Karpathy published his LLM-Wiki Gist, I've been developing for our AIASD Project a module that integrates with our SDLC Orchestrator to provide a searchable, AI-curated knowledge base for humans and AI.

## Background: sdlc-wiki

My initial sdlc-wiki development started in May, as an integration with our SDLC Orchestrator, which:

- Exports the system's AI-generated markdown and imported raw files (PDF, DOCX, etc.) via Azure Function → Logic App → GitHub Private Repo Webhook for an Azure Blob download of the file in `/raw` as markdown
- Triggers the wiki-curation workflow that curates the raw content to wiki content and builds/uploads the QMD (SQLite) blob to Azure
- Triggers a wiki-publish workflow that builds a Quartz site based on the wiki content, and auto-deploys to an Azure SWA linked to the Orchestrator
- Azure Functions, powered by the generated QMD blob, provide natural language search capability in the Orchestrator AI Assistant for querying the wiki, with returned citation links and auto page-following to the sdlc-wiki static web app

Everything works, and all of Karpathy's suggested tools function very well as described — however…

## llm-wiki-starter: A General-Purpose Approach

*Customer data is strictly protected, and there are additional restrictions and considerations that currently impede knowledge base creation on private GitHub Repos.*

Considering this, and my goal to create a more general-purpose, Azure-less LLM-wiki approach for easy reuse anyway, I took the sdlc-wiki learnings and created the **llm-wiki-starter** template repo. It doesn't depend on Azure and can be operated standalone directly in Claude Code or VS Code with the Claude Code extension. Obsidian support continues out of the box — just open an Obsidian vault at the local llm-wiki repo `/wiki` folder.

Domain customizability and multi-repo toolchain maintainability were the primary features needed for an out-of-the-box-ready LLM-wiki. The llm-wiki-starter makes it easy to generate new repos that inherit all the skills and action workflows, including a **wiki-sync** action workflow that syncs the LLM-wiki toolchain from one repo to another via auto-generated pull request — enabling toolchain updates without touching content.

I perform with a local community theater, Kryptonite Radio Theater, and I was given access to the script generation process for one of our shows, and it served well for creating a wiki-curate-scripts skill specifically for show scripts. Everything learned during the curation of the 35-document Kryptonite Radio Theater script domain in llm-wiki-krt was easily synced back to the llm-wiki-starter template. This can also help in understanding how to define the Claude Code skills for other domains.

As a side note: this exercise was useful in determining token costs and action minutes required for curation. It cost approximately 60 €, but was worth the investment.

## Resources

- [llm-wiki-starter (public template)](https://github.com/jambit-AIASD/llm-wiki-starter)
- [llm-wiki-krt (private instance)](https://github.com/dswinscoe/llm-wiki-krt)

> To get started: create a new private repo using the public template.
