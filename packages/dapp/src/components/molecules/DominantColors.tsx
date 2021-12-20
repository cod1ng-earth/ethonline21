import {
  Flex,
  IconButton,
  Skeleton,
  Text,
  useClipboard
} from '@chakra-ui/react';
import { extractColors } from '@splicenft/common';
import { RGB } from 'get-rgba-palette';
import React, { useEffect } from 'react';
import { FaClipboard, FaClipboardCheck } from 'react-icons/fa';
import rgbHex from 'rgb-hex';

export const DominantColorsDisplay = ({ colors }: { colors: RGB[] }) => {
  const { hasCopied, onCopy } = useClipboard(JSON.stringify(colors));

  return (
    <Skeleton isLoaded={colors.length > 0} w="70%" size="lg">
      <Flex direction="row" align="center" height="1.5em" gridGap={0}>
        {colors.map((color) => {
          const colorHex = `#${rgbHex(color[0], color[1], color[2])}`;
          return (
            <Flex key={colorHex} flex="1" background={colorHex}>
              &nbsp;
            </Flex>
          );
        })}
        <Flex>
          <IconButton
            icon={
              hasCopied ? (
                <FaClipboardCheck aria-label="copied" />
              ) : (
                <FaClipboard onClick={onCopy} />
              )
            }
            aria-label="copy palette"
          />
        </Flex>
      </Flex>
    </Skeleton>
  );
};

/**
 * @deprecated don't use. Use your image's src directly
 */
export const DominantColors = ({
  imageUrl,
  dominantColors,
  setDominantColors
}: {
  imageUrl?: string;
  dominantColors: RGB[];
  setDominantColors: (c: RGB[]) => void;
}) => {
  useEffect(() => {
    if (!imageUrl) return;
    (async () => {
      setDominantColors(
        await extractColors(imageUrl, {
          proxy: process.env.REACT_APP_CORS_PROXY
        })
      );
    })();
  }, [imageUrl]);

  return dominantColors.length > 1 ? (
    <Flex>
      <Text>fff</Text>
      <DominantColorsDisplay colors={dominantColors} />
    </Flex>
  ) : (
    <>fdooo</>
  );
};
