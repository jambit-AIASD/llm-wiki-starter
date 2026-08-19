export const CustomOgImagesEmitterName = "CustomOgImages"

export interface ContentDetails {
  slug: string
  title: string
  filePath: string
  links: string[]
  tags: string[]
  content: string
  richContent?: string
  date?: Date
  description?: string
}
