import rss from '@astrojs/rss';
import type { APIContext } from 'astro';

export async function GET(context: APIContext) {
  const postImportResult = import.meta.glob('./posts/*.md', { eager: true });
  const posts = Object.values(postImportResult) as any[];

  const sortedPosts = posts
    .filter(post => !post.frontmatter.title?.includes('（必填）'))
    .sort((a, b) =>
      new Date(b.frontmatter.date).getTime() - new Date(a.frontmatter.date).getTime()
    );

  return rss({
    title: 'Jeffrey0117 技術筆記',
    description: '紀錄開發專案時學到的技術、踩過的坑、一些想法。',
    site: context.site!,
    items: sortedPosts.map(post => ({
      title: post.frontmatter.title,
      pubDate: new Date(post.frontmatter.date),
      description: post.frontmatter.description || '',
      link: `/Evernote/posts/${post.file.split('/').pop()?.replace('.md', '')}/`,
    })),
    customData: `<language>zh-TW</language>`,
  });
}
